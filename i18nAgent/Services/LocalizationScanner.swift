import Foundation

final class LocalizationScanner {

    struct ScanResult {
        let knownRegions: [String]
        let developmentRegion: String?
        let localizationFiles: [LocalizationFile]
        let lprojDirectories: [String: String]
    }

    func scan(projectDir: String, xcodeprojPath: String) -> ScanResult {
        let pbxprojPath = xcodeprojPath + "/project.pbxproj"
        let pbxprojContent = (try? String(contentsOfFile: pbxprojPath, encoding: .utf8)) ?? ""

        let knownRegions = parseKnownRegions(from: pbxprojContent)
        let developmentRegion = parseDevelopmentRegion(from: pbxprojContent)
        let files = findLocalizationFiles(in: projectDir)
        let lprojDirs = findLprojDirectories(in: projectDir)

        return ScanResult(
            knownRegions: knownRegions,
            developmentRegion: developmentRegion,
            localizationFiles: files,
            lprojDirectories: lprojDirs
        )
    }

    func parseKnownRegions(from pbxprojContent: String) -> [String] {
        guard let range = pbxprojContent.range(of: #"knownRegions\s*=\s*\(([\s\S]*?)\)"#, options: .regularExpression) else {
            return []
        }
        let block = String(pbxprojContent[range])
        let regionPattern = #"(\w[\w-]*)"#
        let regex = try? NSRegularExpression(pattern: regionPattern)
        let nsBlock = block as NSString

        var regions: [String] = []
        regex?.enumerateMatches(in: block, range: NSRange(location: 0, length: nsBlock.length)) { match, _, _ in
            guard let match, let range = Range(match.range(at: 1), in: block) else { return }
            let region = String(block[range])
            if region != "knownRegions" {
                regions.append(region)
            }
        }
        return regions
    }

    func parseDevelopmentRegion(from pbxprojContent: String) -> String? {
        guard let range = pbxprojContent.range(of: #"developmentRegion\s*=\s*(\w+)"#, options: .regularExpression) else {
            return nil
        }
        let match = String(pbxprojContent[range])
        return match.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ";", with: "")
    }

    func findLocalizationFiles(in directoryPath: String) -> [LocalizationFile] {
        var results: [LocalizationFile] = []
        let fm = FileManager.default
        let url = URL(fileURLWithPath: directoryPath)

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return results
        }

        var seen = Set<String>()

        for case let fileURL as URL in enumerator {
            let path = fileURL.path
            if path.contains("/Build/") || path.contains("/DerivedData/") ||
               path.contains("/Pods/") || path.contains(".build/") {
                continue
            }

            let ext = fileURL.pathExtension
            guard let format = formatFromExtension(ext) else { continue }

            let baseName = fileURL.lastPathComponent
            let key = "\(baseName)-\(format.rawValue)"

            if !seen.contains(key) {
                seen.insert(key)
                results.append(LocalizationFile(
                    sourcePath: path,
                    format: format,
                    baseName: baseName
                ))
            }
        }

        return results
    }

    func findLprojDirectories(in directoryPath: String) -> [String: String] {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: directoryPath)
        var result: [String: String] = [:]

        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else {
            return result
        }

        for item in contents {
            if item.pathExtension == "lproj" {
                let locale = item.deletingPathExtension().lastPathComponent
                result[locale] = item.path
            }
        }

        for item in contents {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue,
               item.pathExtension != "lproj" {
                if let subContents = try? fm.contentsOfDirectory(
                    at: item,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: .skipsHiddenFiles
                ) {
                    for sub in subContents {
                        if sub.pathExtension == "lproj" {
                            let locale = sub.deletingPathExtension().lastPathComponent
                            if result[locale] == nil {
                                result[locale] = sub.path
                            }
                        }
                    }
                }
            }
        }

        return result
    }

    private func formatFromExtension(_ ext: String) -> LocalizationFile.Format? {
        switch ext {
        case "strings": return .strings
        case "xcstrings": return .xcstrings
        case "stringsdict": return .stringsdict
        case "storyboard": return .storyboard
        case "xib": return .xib
        default: return nil
        }
    }
}
