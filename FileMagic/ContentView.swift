//
//  ContentView.swift
//  FileMagic
//
//  Created by 邓理 on 4/6/25.
//


import SwiftUI
import UniformTypeIdentifiers

struct URLWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

struct ContentView: View {
    @StateObject private var viewModel = ArchiveViewModel()
    @State private var isFilePickerShown = false
    @State private var isArchivePickerShown = false
//    @State private var isShowingShareSheet = false
    @State private var sharedURL: URLWrapper?
    @State private var selectedTab = 0 // 0 表示压缩，1 表示解压，2 表示魔法
    
    // 随机字符串生成器状态
    @State private var randomStringLines = 2
    @State private var includeLetters = true
    @State private var includeNumbers = true
    @State private var includeSpecialChars = false
    @State private var includeChinesePhrases = false
    @State private var stringLength = 10
    @State private var generatedStrings: [String] = []
    @State private var editableStrings: [String] = []
    @State private var customPassword = false
    @State private var customPasswordString: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部标签选择器
                HStack(spacing: 0) {
                    TabButton(title: "压缩", systemImage: "doc.zipper", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    
                    TabButton(title: "解压", systemImage: "folder", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    
                    TabButton(title: "魔法", systemImage: "dice", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                }
                .padding(.horizontal)
                
                // 显示当前状态（压缩中、解压中等）- 只在压缩/解压标签页显示
                if selectedTab < 2 {
                    statusView
                        .padding(.top, 10)
                }
                
                // 主内容区域 - 根据选项卡显示不同内容
                if selectedTab == 0 {
                    compressionView
                } else if selectedTab == 1 {
                    decompressionView
                } else if selectedTab == 2 {
                    randomStringGeneratorView
                }
                
                Spacer()
                
                // 底部操作按钮
                bottomActionButtons
                    .padding()
            }
            .padding(.top)
            .navigationTitle("7z 压缩工具")
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .sheet(isPresented: $isFilePickerShown) {
                DocumentPicker(
                    isPresented: $isFilePickerShown,
                    supportedTypes: [UTType.item],
                    allowsMultipleSelection: true
                ) { urls in
                    viewModel.selectedFiles = urls
                    
                    // 自动开始压缩
                    Task {
                        if !viewModel.password.isEmpty && !viewModel.password2.isEmpty {
                            await viewModel.compressFilesTwice()
                        } else {
                            await viewModel.compressFiles()
                        }
                    }
                }
            }
            .sheet(isPresented: $isArchivePickerShown) {
                DocumentPicker(
                    isPresented: $isArchivePickerShown,
                    supportedTypes: [UTType.archive, UTType.zip],
                    allowsMultipleSelection: false
                ) { urls in
                    guard let url = urls.first else { return }
                    
                    // 自动开始解压
                    Task {
                        if !viewModel.password.isEmpty && !viewModel.password2.isEmpty {
                            await viewModel.decompressFileTwice(url: url)
                        } else {
                            await viewModel.decompressFile(url: url)
                        }
                        
                    }
                }
            }
            .sheet(item: $sharedURL) { item in
                if let url = sharedURL?.url {
                    ShareSheet(item: url)
                }
            }
        }
    }
    
    // 压缩面板
    private var compressionView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 压缩设置面板
                VStack(alignment: .leading, spacing: 16) {
                    Text("压缩设置")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("压缩格式")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("格式", selection: $viewModel.compressionFormat) {
                            Text("7z").tag(ArchiveViewModel.CompressionFormat.sevenZip)
                            Text("ZIP").tag(ArchiveViewModel.CompressionFormat.zip)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // 压缩级别
                        HStack {
                            Text("压缩级别")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(viewModel.compressionLevel)")
                                .font(.headline)
                                .frame(width: 12)
                        }
                        
                        Slider(value: Binding(
                            get: { Float(viewModel.compressionLevel) },
                            set: { viewModel.compressionLevel = UInt8($0) }
                        ), in: 1...9, step: 1)
                        
                        HStack {
                            Text("更快")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("更小")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // 密码设置
                    VStack(alignment: .leading, spacing: 12) {
                        Text("加密选项")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "lock")
                                .foregroundColor(.secondary)
                            TextField("密码 (可选)", text: $viewModel.password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            TextField("密码2（可选）", text:
                                $viewModel.password2)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        if !viewModel.password.isEmpty {
                            Toggle("加密文件列表", isOn: $viewModel.encryptHeader)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // 选择的文件列表
                if !viewModel.selectedFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("已选择的文件")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                viewModel.clearSelectedFiles()
                            }) {
                                Text("清除")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Divider()
                        
                        ForEach(viewModel.selectedFiles, id: \.self) { file in
                            HStack {
                                Image(systemName: "doc")
                                    .foregroundColor(.blue)
                                Text(file.lastPathComponent)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    // 解压面板
    private var decompressionView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 解压密码
                VStack(alignment: .leading, spacing: 16) {
                    Text("解压设置")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("压缩格式")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("格式", selection: $viewModel.compressionFormat) {
                            Text("7z").tag(ArchiveViewModel.CompressionFormat.sevenZip)
                            Text("ZIP").tag(ArchiveViewModel.CompressionFormat.zip)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("加密选项")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Image(systemName: "key")
                                .foregroundColor(.secondary)
                            TextField("输入密码 (如果需要)", text: $viewModel.password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            TextField("输入密码2 (如果需要)", text: $viewModel.password2)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // 解压后的文件列表
                if !viewModel.extractedFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("解压的文件")
                            .font(.headline)
                        
                        Divider()
                        
                        ForEach(viewModel.extractedFiles, id: \.self) { file in
                            HStack {
                                Image(systemName: file.hasDirectoryPath ? "folder" : "doc")
                                    .foregroundColor(file.hasDirectoryPath ? .yellow : .blue)
                                Text(file.lastPathComponent)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    // 随机字符串生成器视图
    private var randomStringGeneratorView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 设置面板
                VStack(alignment: .leading, spacing: 16) {
                    Text("生成设置")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        // 生成行数
                        HStack {
                            Text("生成行数:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Stepper("\(randomStringLines) 行", value: $randomStringLines, in: 1...10)
                                .fixedSize()
                        }
                        
                        // 字符串长度
                        HStack {
                            Text("每行长度:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Stepper("\(stringLength) 字符", value: $stringLength, in: 4...64)
                                .fixedSize()
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        // 字符类型
                        Text("包含字符类型:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Toggle("字母 (A-Z, a-z)", isOn: $includeLetters)
                        Toggle("数字 (0-9)", isOn: $includeNumbers)
                        Toggle("特殊字符 (!@#$%...)", isOn: $includeSpecialChars)
                        Toggle("随机中文短句", isOn: $includeChinesePhrases)
                        Toggle("自定义导入", isOn: $customPassword)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // 自定义导入
                if customPassword {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("自定义字符串")
                                .font(.headline)
                        }
                        
                        Divider()
                        
                        HStack {
                            TextEditor(text: $customPasswordString)
                                .font(.body)
                                .padding(4)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .frame(minHeight: 200)
                        }
                        .padding(.vertical, 4)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // 生成的字符串列表
                if !editableStrings.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("生成的字符串")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                UIPasteboard.general.string = editableStrings.joined(separator: "\n")
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("全部复制")
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            Button(action: {
                                UIPasteboard.general.string = "内：" + editableStrings[0] + "\n外：" + editableStrings[1]
                                viewModel.password = editableStrings[0]
                                viewModel.password2 = editableStrings[1]
                                
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("魔法复制")
                                }
                                .font(.subheadline)
                                .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        
                        Divider()
                        
                        ForEach(0..<editableStrings.count, id: \.self) { index in
                            HStack {
                                Image(systemName: "\(index + 1).circle.fill")
                                    .foregroundColor(.blue)
                                
                                TextField("", text: $editableStrings[index])
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                
                                Button(action: {
                                    UIPasteboard.general.string = editableStrings[index]
                                }) {
                                    Image(systemName: "square.on.square")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var statusView: some View {
        VStack {
            statusContent
        }
        .frame(minHeight: 60)
    }
    
    // 状态视图
    @ViewBuilder
    private var statusContent: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .compressing:
            ProgressWithText(text: "正在压缩...", value: Double(viewModel.progress))
        case .decompressing:
            ProgressWithText(text: "正在解压...", value: Double(viewModel.progress))
        case .listing:
            ProgressWithText(text: "正在列出文件...", value: Double(viewModel.progress))
        case .success(let message):
            VStack(spacing: 10) {
                Text(message)
                    .foregroundColor(.green)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                
                if let url = getLastURL(from: message) {
                    Button(action: {
                        sharedURL = URLWrapper(url: url)
//                        isShowingShareSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("分享文件")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            
        case .error(let message):
            Text(message)
                .foregroundColor(.white)
                .padding()
                .background(Color.red.opacity(0.8))
                .cornerRadius(8)
                .padding(.horizontal)
        }
    }
    
    // 底部操作按钮
    private var bottomActionButtons: some View {
        HStack(spacing: 20) {
            if selectedTab == 0 {
                // 压缩按钮
                ActionButton(
                    icon: "doc.zipper",
                    title: "选择并压缩",
                    action: { isFilePickerShown = true },
                    isDisabled: viewModel.state == .compressing || viewModel.state == .decompressing
                )
            } else if selectedTab == 1 {
                // 解压按钮
                ActionButton(
                    icon: "folder",
                    title: "选择并解压",
                    action: { isArchivePickerShown = true },
                    isDisabled: viewModel.state == .compressing || viewModel.state == .decompressing
                )
            } else {
                // 随机字符串生成按钮
                ActionButton(
                    icon: "wand.and.stars",
                    title: "生成随机字符串",
                    action: generateRandomStrings,
                    isDisabled: false
                )
            }
        }
    }
    
    // 从成功消息中提取URL
    private func getLastURL(from message: String) -> URL? {
        var result = message
        if let resultLine = message.range(of: "\n") {
            result = String(message[resultLine.upperBound...])
        }
        
        if let startRange = result.range(of: ": ") {
            let fileNameSubstring = result[startRange.upperBound...]
            let fileName = String(fileNameSubstring)
            
            // 构建URL
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            if result.contains("压缩完成") {
                return documentsDirectory.appendingPathComponent(fileName)
            } else if result.contains("解压完成") {
                return documentsDirectory.appendingPathComponent(fileName)
            }
        }
        return nil
    }
    
    // 生成随机字符串
    private func generateRandomStrings() {
        if customPassword {
            editableStrings = generateCustomPassword(pwd: customPasswordString)
            return
        }
        
        generatedStrings = []
        
        // 检查是否至少选择了一种字符类型
        if !includeLetters && !includeNumbers && !includeSpecialChars && !includeChinesePhrases {
            // 如果没有选择任何类型，默认使用字母
            includeLetters = true
        }
        
        for _ in 0..<randomStringLines {
            let randomString = generateRandomString(length: stringLength)
            generatedStrings.append(randomString)
        }
        
        // 更新可编辑字符串
        editableStrings = generatedStrings
    }
    
    private func generateRandomString(length: Int) -> String {
        var characters = ""
        
        if includeLetters {
            characters += "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        }
        
        if includeNumbers {
            characters += "0123456789"
        }
        
        if includeSpecialChars {
            characters += "!@#$%^&*()-_=+[]{}|;:,.<>?/"
        }
        
        // 如果选择了中文短句，直接生成中文短句
        if includeChinesePhrases {
            return generateRandomChinesePhrase(approximateLength: length)
        }
        
        // 生成随机字符串
        let charactersArray = Array(characters)
        var result = ""
        
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<charactersArray.count)
            result.append(charactersArray[randomIndex])
        }
        
        return result
    }
    
    private func generateRandomChinesePhrase(approximateLength: Int) -> String {
        // 常用汉字集合
        let commonChineseCharacters = "的一是在不了有和人这中大为上个国我以要他时来用们生到作地于出就分对成会可主发年动同工也能下过子说产种面而方后多定行学法所民得经十三之进着等部度家电力里如水化高自二理起小物现实加量都两体制机当使点从业本去把性好应开它合还因由其些然前外天政四日那社义事平形相全表间样与关各重新线内数正心反你明看原又么利比或但质气第向道命此变条只没结解问意建月公无系军很情者最立代想已通并提直题党程展五果料象员革位入常文总次品式活设及管特件长求老头基资边流路级少图山统接知较将组见计别她手角期根论运农指几九区强放决西被干做必战先回则任取据处队南给色光门即保治北造百规热领七海口东导器压志世金增争济阶油思术极交受联什认六共权收证改清己美再采转更单风切打白教速花带安场身车例真务具万每目至达走积示议声报斗完类八离华名确才科张信马节话米整空元况今集温传土许步群广石记需段研界拉林律叫且究观越织装影算低持音众书布复容儿须际商非验连断深难近矿千周委素技备半办青省列习响约支般史感劳便团往酸历市克何除消构府称太准精值号率族维划选标写存候毛亲快效斯院查江型眼王按格养易置派层片始却专状育厂京识适属圆包火住调满县局照参红细引听该铁价严首底液官德调随病苏失尔死讲配女黄推显谈罪神艺呢席含企望密批营项防举球英氧势告李台落木帮轮破亚师围注远字材排供河态封另施减树溶怎止案言士均武固叶鱼波视仅费紧爱左章早朝害续轻服试食充兵源判护司足某练差致板田降黑犯负击范继兴似余坚曲输修的故城夫够送笑船占右财吃富春职觉汉画功巴跟虽杂飞检吸助升阳互初创抗考投坏策古径换未跑留钢曾端责站简述钱副尽帝射草冲承独令限阿宣环双请超微让控州良轴找否纪益依优顶础载倒房突坐粉敌略客袁冷胜绝析块剂测丝协重诉念陈仍罗盐友洋错苦夜刑移频逐靠混母短皮终聚汽村云哪既距卫停烈央察烧迅境若印洲刻括激孔搞甚室待核校散侵吧甲游久菜味旧模湖货损预阻毫普稳乙妈植息扩银语挥害斤茶武症棋嘛枝树枪析户痛察宣誉详沙梦餐券角康框称贸番寻染房喜测洗胆科割类集遇箱韩食阶底耐迎伸作慢祖旗职篇待星药山读适蛋缺、盖省努集雷外";
        
        var result = ""
        let targetLength = min(approximateLength, 40) // 限制最大长度为40个字符
        
        while result.count < targetLength {
            let randomIndex = Int.random(in: 0..<commonChineseCharacters.count)
            let index = commonChineseCharacters.index(commonChineseCharacters.startIndex, offsetBy: randomIndex)
            result.append(commonChineseCharacters[index])
        }
        
        return result
    }
    
    private func generateCustomPassword(pwd: String) -> [String] {
        var results: [String] = []
        for line in pwd.components(separatedBy: "\n") {
            if let resultLine = line.range(of: "：") {
                results.append(String(line[resultLine.upperBound...]))
            } else {
                results.append(line)
            }
        }
        return results
    }
}

// 自定义标签按钮
struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                Text(title)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(10)
            .overlay(
                isSelected ?
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(.blue)
                        .offset(y: 17)
                    : nil,
                alignment: .bottom
            )
        }
    }
}

// 操作按钮组件
struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    let isDisabled: Bool
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(isDisabled ? Color.gray.opacity(0.3) : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(color: isDisabled ? .clear : Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .disabled(isDisabled)
    }
}

// 进度条带文字组件
struct ProgressWithText: View {
    let text: String
    let value: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: geometry.size.width, height: 8)
                        .opacity(0.1)
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .frame(width: min(CGFloat(value) * geometry.size.width, geometry.size.width), height: 8)
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                        .animation(.linear, value: value)
                }
            }
            .frame(height: 8)
            
            // 百分比显示
            Text("\(Int(value * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ContentView()
}
