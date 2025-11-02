# 시스템 변경사항

 - https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct-GGUF
 - qwen3 에서 공식적으로 GGUF를 발표함.
 - 4b 뿐만 아니라 2b도 발표예정
 - 양자화된 모델이기에 속도의 개선도 충분할것 같음.
 - 

## 해상도를 낮춘 영상 -> vl -> 시계열 db용 json 생성

- 영상 이미지
- <img width="338" height="596" alt="image" src="https://github.com/user-attachments/assets/78436920-a887-402e-83c4-01979bb362e6" />
- 와 같은 영상을 vl 에게 전달하면 다음과 같은 응답을 받을 수 있음.
- vl 응답값
- <img width="704" height="659" alt="image" src="https://github.com/user-attachments/assets/c6ddb75f-13ea-4704-a544-e60db78f312b" />
- 해당 내용을 진작에 사용할 수 있었지만, 너무 느려서 사용하지 않으려 했음.


  
## 제한사항

 - 영상이미지를 그대로 전송해서 쓸 수 있었던 transformers 페키지와 다르게 gguf를 활용하여, lamma cpp 혹은 ollama 서빙은 video 를 현재 지원하지 않음.=
 - 
