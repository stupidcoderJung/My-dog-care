# 1일차

## [지난이야기]
- 이미 nvidia 에서 제공하는 이미지 fewshot 분류 내용의 [예제](https://github.com/NVIDIA/metropolis-nim-workflows/blob/main/nim_workflows/nvdinov2_few_shot/README.md)를 돌려봄
- <img width="500" height="300" alt="image" src="https://github.com/user-attachments/assets/2568c1d9-2550-4fa2-8060-328e73fd5c21" />
- 따라서 우리집 강아지들을 이걸로 분류를 할 수 있지 않을까? 함

## [오늘 할 일]
- [x] 아이폰을 가지고 강아지들 이미지/영상을 찍어둠.
- [x] 이미지 > 압축 > 저장
- [ ] 영상 > 이미지 > 압축 > 저장 이 필요한 상황 ( ai 모델들이 그렇게 고화질이 필요하지 않다고 함.)
- [ ] 압축된 사진들을 가지고 [자동차 데이터 셋](https://huggingface.co/datasets/tanganke/stanford_cars) 처럼 라벨링을 데이터 셋을 만들어야함.

## [고려사항]
- 만일 영상 > 사진 과정에 강아지가 여럿 있거나, 강아지 사진이 사진 전체적으로 콤펙트하게 나오지 않는다면? -> yolo v11 등을 통해, 사진 속 강아지가 있는 곳을 마스킹 -> 사진으로 잘라내어 (강아지가 사진속에 주로 나오게끔) 사용
  
