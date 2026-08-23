import Foundation

public enum PageAuditReportFormatter {
    public static func markdown(bookID: String, result: PageAuditResult) -> String {
        var lines: [String] = []
        lines.append("# Page Audit Report")
        lines.append("")
        lines.append("- book_id: `\(bookID)`")
        lines.append("- ordered_pages: \(result.orderedPageIDs.count)")
        lines.append("- page_number_observations: \(result.pageNumberObservations.count)")
        lines.append("- duplicate_groups: \(result.duplicateGroups.count)")
        lines.append("- missing_page_suspicions: \(result.missingPageSuspicions.count)")
        lines.append("- reversal_events: \(result.reversalEvents.count)")
        lines.append("- auto_fixes: \(result.autoFixes.count)")
        lines.append("- review_required: \(result.reviewRequired.count)")
        lines.append("")

        lines.append("## Final order")
        if result.orderedPageIDs.isEmpty {
            lines.append("- none")
        } else {
            for (index, pageID) in result.orderedPageIDs.enumerated() {
                lines.append("- \(index + 1): `\(pageID)`")
            }
        }
        lines.append("")

        lines.append("## Page number observations")
        if result.pageNumberObservations.isEmpty {
            lines.append("- none")
        } else {
            for observation in result.pageNumberObservations {
                lines.append("- `\(observation.pageID)`: \(observation.value), confidence=\(format(observation.confidence)), score=\(format(observation.score)), rotation=\(observation.rotationDegrees)")
            }
        }
        lines.append("")

        lines.append("## Missing page suspicions")
        if result.missingPageSuspicions.isEmpty {
            lines.append("- none")
        } else {
            for item in result.missingPageSuspicions {
                let expected = item.expectedPageNumbers.map(String.init).joined(separator: ",")
                lines.append("- `\(item.afterPageID)` → `\(item.beforePageID)`: expected [\(expected)], confidence=\(format(item.confidence)), evidence=\(evidence(item.evidence))")
            }
        }
        lines.append("")

        lines.append("## Reversal events")
        if result.reversalEvents.isEmpty {
            lines.append("- none")
        } else {
            for event in result.reversalEvents {
                lines.append("- `\(event.leftPageID)` ↔ `\(event.rightPageID)`: numbers=\(event.observedNumbers), confidence=\(format(event.confidence)), evidence=\(evidence(event.evidence))")
            }
        }
        lines.append("")

        lines.append("## Duplicate groups")
        if result.duplicateGroups.isEmpty {
            lines.append("- none")
        } else {
            for group in result.duplicateGroups {
                lines.append("- \(group.pageIDs.map { "`\($0)`" }.joined(separator: ", ")): confidence=\(format(group.confidence)), evidence=\(evidence(group.evidence))")
            }
        }
        lines.append("")

        lines.append("## Auto fixes")
        if result.autoFixes.isEmpty {
            lines.append("- none")
        } else {
            for fix in result.autoFixes {
                lines.append("- \(fix.kind.rawValue): \(fix.pageIDs.map { "`\($0)`" }.joined(separator: ", ")), confidence=\(format(fix.confidence)) — \(fix.rationale)")
            }
        }
        lines.append("")

        lines.append("## Review required")
        if result.reviewRequired.isEmpty {
            lines.append("- none")
        } else {
            for item in result.reviewRequired {
                lines.append("- \(item.reason.rawValue): \(item.pageIDs.map { "`\($0)`" }.joined(separator: ", ")), confidence=\(format(item.confidence)) — \(item.detail)")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func evidence(_ sources: [PageAuditEvidenceSource]) -> String {
        sources.map(\.rawValue).joined(separator: ",")
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
