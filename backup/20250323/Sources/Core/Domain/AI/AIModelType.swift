public enum AIModelType: String {
    case textProcessing = "text_processing"
    case imageGeneration = "image_generation"
    case textToSpeech = "text_to_speech"
    case speechToText = "speech_to_text"
    case translation = "translation"
    case summarization = "summarization"
    case questionAnswering = "question_answering"
    
    public var displayName: String {
        switch self {
        case .textProcessing:
            return "Text Processing"
        case .imageGeneration:
            return "Image Generation"
        case .textToSpeech:
            return "Text to Speech"
        case .speechToText:
            return "Speech to Text"
        case .translation:
            return "Translation"
        case .summarization:
            return "Summarization"
        case .questionAnswering:
            return "Question Answering"
        }
    }
    
    public var description: String {
        switch self {
        case .textProcessing:
            return "Process and analyze text content"
        case .imageGeneration:
            return "Generate images from text descriptions"
        case .textToSpeech:
            return "Convert text to natural-sounding speech"
        case .speechToText:
            return "Convert speech to text"
        case .translation:
            return "Translate text between languages"
        case .summarization:
            return "Generate concise summaries of text"
        case .questionAnswering:
            return "Answer questions based on context"
        }
    }
    
    public var defaultModel: String {
        switch self {
        case .textProcessing:
            return "deepseek-coder"
        case .imageGeneration:
            return "stable-diffusion"
        case .textToSpeech:
            return "elevenlabs"
        case .speechToText:
            return "whisper"
        case .translation:
            return "deepl"
        case .summarization:
            return "gpt-4"
        case .questionAnswering:
            return "gpt-4"
        }
    }
} 