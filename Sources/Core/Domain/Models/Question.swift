import Foundation

/// 问题模型
public struct Question: Codable, Identifiable, Hashable {
    /// 问题ID
    public let id: UUID
    
    /// 问题文本
    public let text: String
    
    /// 问题类型
    public let type: QuestionType
    
    /// 问题难度
    public let difficulty: QuestionDifficulty
    
    /// 问题标签
    public let tags: [String]
    
    /// 可能的答案（如果是选择题）
    public let options: [String]?
    
    /// 正确答案
    public let answer: String?
    
    /// 问题来源位置（在原文档中的位置）
    public let sourcePosition: Int?
    
    /// 初始化方法
    public init(
        id: UUID = UUID(),
        text: String,
        type: QuestionType = .openEnd,
        difficulty: QuestionDifficulty = .medium,
        tags: [String] = [],
        options: [String]? = nil,
        answer: String? = nil,
        sourcePosition: Int? = nil
    ) {
        self.id = id
        self.text = text
        self.type = type
        self.difficulty = difficulty
        self.tags = tags
        self.options = options
        self.answer = answer
        self.sourcePosition = sourcePosition
    }
    
    // MARK: - Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    public static func == (lhs: Question, rhs: Question) -> Bool {
        return lhs.id == rhs.id
    }
}

/// 问题类型
public enum QuestionType: String, Codable {
    case multipleChoice = "multipleChoice"
    case trueFalse = "trueFalse"
    case openEnd = "openEnd"
    case completion = "completion"
    case matching = "matching"
}

/// 问题难度
public enum QuestionDifficulty: String, Codable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    case expert = "expert"
} 