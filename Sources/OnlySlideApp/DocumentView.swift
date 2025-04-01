import SwiftUI

/// 文档视图，展示分析后的文档内容
struct DocumentView: View {
    let document: DocumentAnalysisResult
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(document.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom)
                
                ForEach(0..<document.content.sections.count, id: \.self) { sectionIndex in
                    let section = document.content.sections[sectionIndex]
                    
                    Text(section.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top)
                    
                    ForEach(0..<section.items.count, id: \.self) { itemIndex in
                        contentItemView(section.items[itemIndex])
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    func contentItemView(_ item: DocumentContent.ContentItem) -> some View {
        switch item {
        case .text(let text):
            Text(text)
                .padding(.vertical, 4)
        
        case .list(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.indices, id: \.self) { index in
                    HStack(alignment: .top) {
                        Text("•")
                            .padding(.trailing, 4)
                        Text(items[index])
                    }
                }
            }
            .padding(.vertical, 4)
            
        case .table(let rows):
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 0) {
                        ForEach(rows[rowIndex].indices, id: \.self) { colIndex in
                            Text(rows[rowIndex][colIndex])
                                .padding(8)
                                .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                                .background(rowIndex == 0 ? Color.secondary.opacity(0.2) : (rowIndex % 2 == 1 ? Color.secondary.opacity(0.1) : Color.clear))
                                .border(Color.secondary.opacity(0.3), width: 0.5)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            
        case .code(let code, let language):
            VStack(alignment: .leading, spacing: 4) {
                Text(language)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                }
            }
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding(.vertical, 4)
            
        case .quote(let text, let author):
            VStack(alignment: .leading, spacing: 8) {
                Text("\"\(text)\"")
                    .italic()
                    .padding(.horizontal)
                
                if let author = author {
                    Text("— \(author)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding(.vertical, 4)
            
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(8)
                .padding(.vertical, 4)
        }
    }
} 