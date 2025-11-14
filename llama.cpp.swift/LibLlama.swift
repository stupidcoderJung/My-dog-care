import Foundation
import llama

enum LlamaError: Error {
    case couldNotInitializeContext
    case couldNotInitializeProjector
    case invalidVisionInput
    case failedToTokenizeVisionPrompt
    case failedToEvaluateVisionPrompt
}

struct VisionResponse {
    let text: String
    let embedding: Data?
}

func llama_batch_clear(_ batch: inout llama_batch) {
    batch.n_tokens = 0
}

func llama_batch_add(_ batch: inout llama_batch, _ id: llama_token, _ pos: llama_pos, _ seq_ids: [llama_seq_id], _ logits: Bool) {
    batch.token   [Int(batch.n_tokens)] = id
    batch.pos     [Int(batch.n_tokens)] = pos
    batch.n_seq_id[Int(batch.n_tokens)] = Int32(seq_ids.count)
    for i in 0..<seq_ids.count {
        batch.seq_id[Int(batch.n_tokens)]![Int(i)] = seq_ids[i]
    }
    batch.logits  [Int(batch.n_tokens)] = logits ? 1 : 0

    batch.n_tokens += 1
}

actor LlamaContext {
    private var model: OpaquePointer
    private var context: OpaquePointer
    private var vocab: OpaquePointer
    private var sampling: UnsafeMutablePointer<llama_sampler>
    private var batch: llama_batch
    private var tokens_list: [llama_token]
    var is_done: Bool = false

    /// This variable is used to store temporarily invalid cchars
    private var temporary_invalid_cchars: [CChar]

    var n_len: Int32 = 1024
    var n_cur: Int32 = 0

    var n_decode: Int32 = 0

    init(model: OpaquePointer, context: OpaquePointer) {
        self.model = model
        self.context = context
        self.tokens_list = []
        self.batch = llama_batch_init(512, 0, 1)
        self.temporary_invalid_cchars = []
        let sparams = llama_sampler_chain_default_params()
        self.sampling = llama_sampler_chain_init(sparams)
        llama_sampler_chain_add(self.sampling, llama_sampler_init_temp(0.4))
        llama_sampler_chain_add(self.sampling, llama_sampler_init_dist(1234))
        vocab = llama_model_get_vocab(model)
    }

    deinit {
        llama_sampler_free(sampling)
        llama_batch_free(batch)
        llama_model_free(model)
        llama_free(context)
        llama_backend_free()
    }

    static func create_context(path: String) throws -> LlamaContext {
        llama_backend_init()
        var model_params = llama_model_default_params()

#if targetEnvironment(simulator)
        model_params.n_gpu_layers = 0
        print("Running on simulator, force use n_gpu_layers = 0")
#else
        model_params.n_gpu_layers = Int32.max
        print("Running on device, offloading all layers to Metal")
#endif
        let model = llama_model_load_from_file(path, model_params)
        guard let model else {
            print("Could not load model at \(path)")
            throw LlamaError.couldNotInitializeContext
        }

        let n_threads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        print("Using \(n_threads) threads")

        var ctx_params = llama_context_default_params()
        ctx_params.n_ctx = 2048
        ctx_params.n_threads       = Int32(n_threads)
        ctx_params.n_threads_batch = Int32(n_threads)

        let context = llama_init_from_model(model, ctx_params)
        guard let context else {
            print("Could not load context!")
            throw LlamaError.couldNotInitializeContext
        }

        return LlamaContext(model: model, context: context)
    }

    func model_info() -> String {
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        result.initialize(repeating: Int8(0), count: 256)
        defer {
            result.deallocate()
        }

        // TODO: this is probably very stupid way to get the string from C

        let nChars = llama_model_desc(model, result, 256)
        let bufferPointer = UnsafeBufferPointer(start: result, count: Int(nChars))

        var SwiftString = ""
        for char in bufferPointer {
            SwiftString.append(Character(UnicodeScalar(UInt8(char))))
        }

        return SwiftString
    }

    func modelPointer() -> OpaquePointer {
        return model
    }

    func get_n_tokens() -> Int32 {
        return batch.n_tokens;
    }

    func completion_init(text: String) {
        print("attempting to complete \"\(text)\"")

        tokens_list = tokenize(text: text, add_bos: true)
        temporary_invalid_cchars = []

        let n_ctx = llama_n_ctx(context)
        let n_kv_req = tokens_list.count + (Int(n_len) - tokens_list.count)

        print("\n n_len = \(n_len), n_ctx = \(n_ctx), n_kv_req = \(n_kv_req)")

        if n_kv_req > n_ctx {
            print("error: n_kv_req > n_ctx, the required KV cache size is not big enough")
        }

        for id in tokens_list {
            print(String(cString: token_to_piece(token: id) + [0]))
        }

        llama_batch_clear(&batch)

        for i1 in 0..<tokens_list.count {
            let i = Int(i1)
            llama_batch_add(&batch, tokens_list[i], Int32(i), [0], false)
        }
        batch.logits[Int(batch.n_tokens) - 1] = 1 // true

        if llama_decode(context, batch) != 0 {
            print("llama_decode() failed")
        }

        n_cur = batch.n_tokens
    }

    func completion_loop() -> String {
        var new_token_id: llama_token = 0

        new_token_id = llama_sampler_sample(sampling, context, batch.n_tokens - 1)

        if llama_vocab_is_eog(vocab, new_token_id) || n_cur == n_len {
            print("\n")
            is_done = true
            let new_token_str = String(cString: temporary_invalid_cchars + [0])
            temporary_invalid_cchars.removeAll()
            return new_token_str
        }

        let new_token_str = appendTokenPiece(new_token_id)
        print(new_token_str)
        // tokens_list.append(new_token_id)

        llama_batch_clear(&batch)
        llama_batch_add(&batch, new_token_id, n_cur, [0], true)

        n_decode += 1
        n_cur    += 1

        if llama_decode(context, batch) != 0 {
            print("failed to evaluate llama!")
        }

        return new_token_str
    }

    func bench(pp: Int, tg: Int, pl: Int, nr: Int = 1) -> String {
        var pp_avg: Double = 0
        var tg_avg: Double = 0

        var pp_std: Double = 0
        var tg_std: Double = 0

        for _ in 0..<nr {
            // bench prompt processing

            llama_batch_clear(&batch)

            let n_tokens = pp

            for i in 0..<n_tokens {
                llama_batch_add(&batch, 0, Int32(i), [0], false)
            }
            batch.logits[Int(batch.n_tokens) - 1] = 1 // true

            llama_memory_clear(llama_get_memory(context), false)

            let t_pp_start = DispatchTime.now().uptimeNanoseconds / 1000;

            if llama_decode(context, batch) != 0 {
                print("llama_decode() failed during prompt")
            }
            llama_synchronize(context)

            let t_pp_end = DispatchTime.now().uptimeNanoseconds / 1000;

            // bench text generation

            llama_memory_clear(llama_get_memory(context), false)

            let t_tg_start = DispatchTime.now().uptimeNanoseconds / 1000;

            for i in 0..<tg {
                llama_batch_clear(&batch)

                for j in 0..<pl {
                    llama_batch_add(&batch, 0, Int32(i), [Int32(j)], true)
                }

                if llama_decode(context, batch) != 0 {
                    print("llama_decode() failed during text generation")
                }
                llama_synchronize(context)
            }

            let t_tg_end = DispatchTime.now().uptimeNanoseconds / 1000;

            llama_memory_clear(llama_get_memory(context), false)

            let t_pp = Double(t_pp_end - t_pp_start) / 1000000.0
            let t_tg = Double(t_tg_end - t_tg_start) / 1000000.0

            let speed_pp = Double(pp)    / t_pp
            let speed_tg = Double(pl*tg) / t_tg

            pp_avg += speed_pp
            tg_avg += speed_tg

            pp_std += speed_pp * speed_pp
            tg_std += speed_tg * speed_tg

            print("pp \(speed_pp) t/s, tg \(speed_tg) t/s")
        }

        pp_avg /= Double(nr)
        tg_avg /= Double(nr)

        if nr > 1 {
            pp_std = sqrt(pp_std / Double(nr - 1) - pp_avg * pp_avg * Double(nr) / Double(nr - 1))
            tg_std = sqrt(tg_std / Double(nr - 1) - tg_avg * tg_avg * Double(nr) / Double(nr - 1))
        } else {
            pp_std = 0
            tg_std = 0
        }

        let model_desc     = model_info();
        let model_size     = String(format: "%.2f GiB", Double(llama_model_size(model)) / 1024.0 / 1024.0 / 1024.0);
        let model_n_params = String(format: "%.2f B", Double(llama_model_n_params(model)) / 1e9);
        let backend        = "Metal";
        let pp_avg_str     = String(format: "%.2f", pp_avg);
        let tg_avg_str     = String(format: "%.2f", tg_avg);
        let pp_std_str     = String(format: "%.2f", pp_std);
        let tg_std_str     = String(format: "%.2f", tg_std);

        var result = ""

        result += String("| model | size | params | backend | test | t/s |\n")
        result += String("| --- | --- | --- | --- | --- | --- |\n")
        result += String("| \(model_desc) | \(model_size) | \(model_n_params) | \(backend) | pp \(pp) | \(pp_avg_str) ± \(pp_std_str) |\n")
        result += String("| \(model_desc) | \(model_size) | \(model_n_params) | \(backend) | tg \(tg) | \(tg_avg_str) ± \(tg_std_str) |\n")

        return result;
    }

    func clear() {
        tokens_list.removeAll()
        temporary_invalid_cchars.removeAll()
        llama_memory_clear(llama_get_memory(context), true)
    }

    private func tokenize(text: String, add_bos: Bool) -> [llama_token] {
        let utf8Count = text.utf8.count
        let n_tokens = utf8Count + (add_bos ? 1 : 0) + 1
        let tokens = UnsafeMutablePointer<llama_token>.allocate(capacity: n_tokens)
        let tokenCount = llama_tokenize(vocab, text, Int32(utf8Count), tokens, Int32(n_tokens), add_bos, false)

        var swiftTokens: [llama_token] = []
        for i in 0..<tokenCount {
            swiftTokens.append(tokens[Int(i)])
        }

        tokens.deallocate()

        return swiftTokens
    }

    /// - note: The result does not contain null-terminator
    private func token_to_piece(token: llama_token) -> [CChar] {
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: 8)
        result.initialize(repeating: Int8(0), count: 8)
        defer {
            result.deallocate()
        }
        let nTokens = llama_token_to_piece(vocab, token, result, 8, 0, false)

        if nTokens < 0 {
            let newResult = UnsafeMutablePointer<Int8>.allocate(capacity: Int(-nTokens))
            newResult.initialize(repeating: Int8(0), count: Int(-nTokens))
            defer {
                newResult.deallocate()
            }
            let nNewTokens = llama_token_to_piece(vocab, token, newResult, -nTokens, 0, false)
            let bufferPointer = UnsafeBufferPointer(start: newResult, count: Int(nNewTokens))
            return Array(bufferPointer)
        } else {
            let bufferPointer = UnsafeBufferPointer(start: result, count: Int(nTokens))
            return Array(bufferPointer)
        }
    }
}

extension LlamaContext {
    func generateVisionResponse(
        prompt: String,
        imageData: [Data],
        projector: MultimodalProjector,
        maxTokens: Int32 = 128
    ) async throws -> VisionResponse {
        guard !imageData.isEmpty else {
            throw LlamaError.invalidVisionInput
        }

        guard let chunks = mtmd_input_chunks_init() else {
            throw LlamaError.failedToTokenizeVisionPrompt
        }
        defer { mtmd_input_chunks_free(chunks) }

        let mmContext = projector.contextPointer
        var bitmaps: [OpaquePointer?] = []
        defer {
            bitmaps.compactMap { $0 }.forEach { mtmd_bitmap_free($0) }
        }
        bitmaps.reserveCapacity(imageData.count)

        for data in imageData {
            let bitmap = data.withUnsafeBytes { buffer -> OpaquePointer? in
                guard let baseAddress = buffer.bindMemory(to: UInt8.self).baseAddress else {
                    return nil
                }
                return mtmd_helper_bitmap_init_from_buf(mmContext, baseAddress, data.count)
            }
            guard let bitmap else {
                throw LlamaError.invalidVisionInput
            }
            bitmaps.append(bitmap)
        }

        let promptWithMarkers = ensureMarker(in: prompt, count: imageData.count)

        #if DEBUG
        print("[Vision Prompt] \(promptWithMarkers)")
        #endif

        let bitmapCount = bitmaps.count
        try bitmaps.withUnsafeMutableBufferPointer { pointer in
            try promptWithMarkers.withCString { cString in
                var text = mtmd_input_text(text: cString, add_special: true, parse_special: true)
                let result = withUnsafePointer(to: &text) { textPointer in
                    mtmd_tokenize(
                        mmContext,
                        chunks,
                        textPointer,
                        pointer.baseAddress,
                        bitmapCount
                    )
                }
                guard result == 0 else {
                    throw LlamaError.failedToTokenizeVisionPrompt
                }
            }
        }

        llama_memory_clear(llama_get_memory(context), true)
        llama_batch_clear(&batch)
        tokens_list.removeAll()
        temporary_invalid_cchars.removeAll()
        n_decode = 0

        var nPast: llama_pos = 0
        let chunkCount = mtmd_input_chunks_size(chunks)
        let visionEmbeddingDim = Int(llama_model_n_embd_inp(model))
        var capturedEmbedding: Data?

        for index in 0..<chunkCount {
            guard let chunk = mtmd_input_chunks_get(chunks, index) else { continue }
            let chunkType = mtmd_input_chunk_get_type(chunk)
            var chunkPast = nPast
            let isLast = index == chunkCount - 1
            let evalResult = mtmd_helper_eval_chunk_single(
                mmContext,
                context,
                chunk,
                nPast,
                0,
                Int32(llama_n_batch(context)),
                isLast,
                &chunkPast
            )
            guard evalResult == 0 else {
                throw LlamaError.failedToEvaluateVisionPrompt
            }
            nPast = chunkPast
            if chunkType == MTMD_INPUT_CHUNK_TYPE_IMAGE && capturedEmbedding == nil,
               let embdPointer = mtmd_get_output_embd(mmContext) {
                let tokenCount = Int(mtmd_input_chunk_get_n_tokens(chunk))
                let floatCount = tokenCount * visionEmbeddingDim
                let buffer = UnsafeBufferPointer(start: embdPointer, count: floatCount)
                capturedEmbedding = Data(buffer: buffer)
            }
        }

        n_cur = nPast

        var generated = ""
        var tokensGenerated: Int32 = 0

        while tokensGenerated < maxTokens {
            let token = llama_sampler_sample(sampling, context, -1)
            if llama_vocab_is_eog(vocab, token) {
                break
            }

            generated += appendTokenPiece(token)

            llama_batch_clear(&batch)
            llama_batch_add(&batch, token, nPast, [0], true)
            nPast += 1
            n_cur = nPast
            n_decode += 1

            if llama_decode(context, batch) != 0 {
                throw LlamaError.failedToEvaluateVisionPrompt
            }

            tokensGenerated += 1
        }

        let text = generated.trimmingCharacters(in: .whitespacesAndNewlines)
        return VisionResponse(text: text, embedding: capturedEmbedding)
    }

    private func ensureMarker(in prompt: String, count: Int) -> String {
        guard count > 0 else { return prompt }
        let marker = String(cString: mtmd_default_marker())
        let existing = prompt.components(separatedBy: marker).count - 1
        guard existing < count else { return prompt }

        var updated = prompt
        for _ in existing..<count {
            if !updated.hasSuffix("\n") {
                updated += "\n"
            }
            updated += marker
        }
        return updated
    }

    fileprivate func appendTokenPiece(_ token: llama_token) -> String {
        temporary_invalid_cchars.append(contentsOf: token_to_piece(token: token))
        if let string = String(validatingUTF8: temporary_invalid_cchars + [0]) {
            temporary_invalid_cchars.removeAll()
            return string
        } else if (0 ..< temporary_invalid_cchars.count).contains(where: { idx in
            idx != 0 && String(validatingUTF8: Array(temporary_invalid_cchars.suffix(idx)) + [0]) != nil
        }) {
            let string = String(cString: temporary_invalid_cchars + [0])
            temporary_invalid_cchars.removeAll()
            return string
        }
        return ""
    }
}

final class MultimodalProjector {
    private let context: OpaquePointer

    private init(context: OpaquePointer) {
        self.context = context
    }

    var contextPointer: OpaquePointer { context }

    deinit {
        mtmd_free(context)
    }

    static func create(mmprojPath: String, textModelPointer: OpaquePointer) async throws -> MultimodalProjector {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var params = mtmd_context_params_default()
                params.use_gpu = true
                params.print_timings = false
                params.media_marker = mtmd_default_marker()
                params.n_threads = Int32(max(2, ProcessInfo.processInfo.activeProcessorCount))

                guard let projectorContext = mtmd_init_from_file(mmprojPath, textModelPointer, params) else {
                    continuation.resume(throwing: LlamaError.couldNotInitializeProjector)
                    return
                }

                continuation.resume(returning: MultimodalProjector(context: projectorContext))
            }
        }
    }
}

extension MultimodalProjector: @unchecked Sendable {}

extension LlamaError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .couldNotInitializeContext:
            return "텍스트 모델을 초기화할 수 없어요."
        case .couldNotInitializeProjector:
            return "멀티모달 projector를 초기화할 수 없어요."
        case .invalidVisionInput:
            return "이미지 데이터를 처리할 수 없어요."
        case .failedToTokenizeVisionPrompt:
            return "AI 요청을 준비하지 못했어요."
        case .failedToEvaluateVisionPrompt:
            return "AI 응답을 생성하지 못했어요."
        }
    }
}
