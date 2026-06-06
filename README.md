Dog Breed Classifier

An iOS app that identifies dog breeds from a photo or live camera feed using on-device machine learning.

The app uses **Core ML** and **Vision** to classify dog breeds and display a prediction with a confidence score — all without requiring an internet connection.

## Features

* Classify dog breeds using the camera
* Select images from the photo library
* On-device ML inference with Core ML
* Vision framework integration
* Fast, responsive UI with Swift Concurrency
* Built with SwiftUI and MVVM architecture

## Tech Stack

* SwiftUI
* Core ML
* Vision
* Swift Concurrency (`async/await`)
* MVVM Architecture

## How It Works

1. Take a photo or select one from your library.
2. The image is processed using Vision.
3. A Core ML model predicts the dog's breed.
4. The top prediction and confidence score are displayed.

## Future Improvements

* Support multiple dogs in one image
* Show additional breed information
* Save classification history
* Improve model accuracy
