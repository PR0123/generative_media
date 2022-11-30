# Generative Media

https://user-images.githubusercontent.com/81814529/204860919-e0fec36d-7451-49d1-ab2b-ee23124409a1.mov

Questions:
- Generating audio noice can be done with configuring a buffer and filling with random Floats.
What would be the video equivalent to generate uncompressed analog TV static in real time?
See: https://developer.apple.com/forums/thread/720986. Here is [an unacceptable solution](fillBufferPainfulyLong.swift) that takes forever.

- How to handle replacing proposed usleep with native methods for requesting data? See: https://developer.apple.com/forums/thread/720647

- Why some video files will report 0 duration, and what it has to do with audio formats? See: https://developer.apple.com/forums/thread/720633



