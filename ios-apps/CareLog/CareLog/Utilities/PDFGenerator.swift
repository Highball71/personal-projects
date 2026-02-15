import UIKit
import PDFKit

struct PDFGenerator {
    
    static func generateDailySummary(patient: Patient, date: Date, entries: [CareEntry], shifts: [Shift]) -> Data {
        let pageWidth: CGFloat = 612 // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - (margin * 2)
        
        let pdfMetaData: [String: Any] = [
            kCGPDFContextTitle as String: "Care Log — \(patient.firstName) — \(dateString(date))",
            kCGPDFContextCreator as String: "CareLog App"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData
        
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )
        
        let data = renderer.pdfData { context in
            context.beginPage()
            var yPosition: CGFloat = margin
            
            // MARK: - Header
            let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
            let subtitleFont = UIFont.systemFont(ofSize: 14, weight: .medium)
            let bodyFont = UIFont.systemFont(ofSize: 11, weight: .regular)
            let boldBodyFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
            let sectionFont = UIFont.systemFont(ofSize: 14, weight: .bold)
            let smallFont = UIFont.systemFont(ofSize: 9, weight: .regular)
            
            let titleColor = UIColor(red: 0.17, green: 0.37, blue: 0.54, alpha: 1.0)
            let accentColor = UIColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
            
            // App name + logo line
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: titleColor
            ]
            let headerText = "CareLog — Daily Summary"
            headerText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttrs)
            yPosition += 30
            
            // Divider line
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: margin, y: yPosition))
            dividerPath.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            accentColor.setStroke()
            dividerPath.lineWidth = 2
            dividerPath.stroke()
            yPosition += 10
            
            // Patient name and date
            let patientAttrs: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.darkGray
            ]
            "Patient: \(patient.firstName)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: patientAttrs)
            
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.darkGray
            ]
            let dateStr = dateString(date)
            let dateSize = dateStr.size(withAttributes: dateAttrs)
            dateStr.draw(at: CGPoint(x: pageWidth - margin - dateSize.width, y: yPosition), withAttributes: dateAttrs)
            yPosition += 25
            
            // Shift info
            let dayShifts = shifts.filter {
                Calendar.current.isDate($0.startTime, inSameDayAs: date)
            }
            if !dayShifts.isEmpty {
                let totalHours = dayShifts.reduce(0.0) { $0 + $1.durationDecimalHours }
                let shiftText = "Shift Hours: \(String(format: "%.1f", totalHours)) hrs (\(dayShifts.count) shift\(dayShifts.count == 1 ? "" : "s"))"
                shiftText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: [
                    .font: bodyFont, .foregroundColor: UIColor.darkGray
                ])
                yPosition += 20
            }
            
            yPosition += 5
            
            // MARK: - Entries by Type
            let groupedEntries = Dictionary(grouping: entries) { $0.entryType }
            let typeOrder: [EntryType] = [.vitals, .medication, .meal, .activity, .mood, .bowelBladder, .woundCare, .therapy, .note]
            
            for entryType in typeOrder {
                guard let typeEntries = groupedEntries[entryType], !typeEntries.isEmpty else { continue }
                
                // Check if we need a new page
                if yPosition > pageHeight - 100 {
                    // Footer on current page
                    drawFooter(context: context, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, font: smallFont)
                    context.beginPage()
                    yPosition = margin
                }
                
                // Section header
                let sectionAttrs: [NSAttributedString.Key: Any] = [
                    .font: sectionFont,
                    .foregroundColor: titleColor
                ]
                entryType.rawValue.uppercased().draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttrs)
                yPosition += 22
                
                // Section divider
                let sectionDivider = UIBezierPath()
                sectionDivider.move(to: CGPoint(x: margin, y: yPosition))
                sectionDivider.addLine(to: CGPoint(x: margin + contentWidth, y: yPosition))
                UIColor.lightGray.setStroke()
                sectionDivider.lineWidth = 0.5
                sectionDivider.stroke()
                yPosition += 8
                
                // Entries
                let sortedEntries = typeEntries.sorted { $0.timestamp < $1.timestamp }
                for entry in sortedEntries {
                    if yPosition > pageHeight - 80 {
                        drawFooter(context: context, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, font: smallFont)
                        context.beginPage()
                        yPosition = margin
                    }
                    
                    // Time
                    let timeAttrs: [NSAttributedString.Key: Any] = [
                        .font: boldBodyFont,
                        .foregroundColor: UIColor.darkGray
                    ]
                    entry.timeString.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: timeAttrs)
                    
                    // Summary text (wrapped)
                    let summaryText = entry.summary
                    let summaryAttrs: [NSAttributedString.Key: Any] = [
                        .font: bodyFont,
                        .foregroundColor: UIColor.black
                    ]
                    let summaryX: CGFloat = margin + 65
                    let summaryWidth = contentWidth - 65
                    let summaryRect = CGRect(x: summaryX, y: yPosition, width: summaryWidth, height: 200)
                    let summarySize = summaryText.boundingRect(
                        with: CGSize(width: summaryWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin],
                        attributes: summaryAttrs,
                        context: nil
                    )
                    summaryText.draw(in: summaryRect, withAttributes: summaryAttrs)
                    
                    // Additional notes
                    if !entry.noteText.isEmpty && entry.entryType != .note {
                        let noteY = yPosition + summarySize.height + 2
                        let noteAttrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.italicSystemFont(ofSize: 10),
                            .foregroundColor: UIColor.gray
                        ]
                        let noteText = "Note: \(entry.noteText)"
                        noteText.draw(in: CGRect(x: summaryX, y: noteY, width: summaryWidth, height: 100), withAttributes: noteAttrs)
                        yPosition += summarySize.height + 18
                    } else {
                        yPosition += max(summarySize.height + 6, 18)
                    }
                    
                    // Photo indicator
                    if !entry.photoData.isEmpty {
                        let photoText = "📷 \(entry.photoData.count) photo\(entry.photoData.count == 1 ? "" : "s") attached"
                        photoText.draw(at: CGPoint(x: margin + 65, y: yPosition), withAttributes: [
                            .font: smallFont, .foregroundColor: UIColor.systemBlue
                        ])
                        yPosition += 14
                    }
                }
                
                yPosition += 12
            }
            
            // Footer
            drawFooter(context: context, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, font: smallFont)
        }
        
        return data
    }
    
    private static func drawFooter(context: UIGraphicsPDFRendererContext, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat, font: UIFont) {
        let footerY = pageHeight - 30
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.lightGray
        ]
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let generated = "Generated by CareLog · \(formatter.string(from: Date()))"
        let size = generated.size(withAttributes: footerAttrs)
        generated.draw(at: CGPoint(x: (pageWidth - size.width) / 2, y: footerY), withAttributes: footerAttrs)
        
        let disclaimer = "For personal care documentation only. Not a medical record."
        let disclaimerSize = disclaimer.size(withAttributes: footerAttrs)
        disclaimer.draw(at: CGPoint(x: (pageWidth - disclaimerSize.width) / 2, y: footerY + 12), withAttributes: footerAttrs)
    }
    
    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    // MARK: - Mileage Report
    static func generateMileageReport(entries: [MileageEntry], dateRange: String) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - (margin * 2)
        
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: UIGraphicsPDFRendererFormat()
        )
        
        let data = renderer.pdfData { context in
            context.beginPage()
            var yPosition: CGFloat = margin
            
            let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
            let bodyFont = UIFont.systemFont(ofSize: 11, weight: .regular)
            let boldFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
            
            // Title
            "Mileage Log — \(dateRange)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: [
                .font: titleFont, .foregroundColor: UIColor(red: 0.17, green: 0.37, blue: 0.54, alpha: 1.0)
            ])
            yPosition += 35
            
            // Column headers
            let headers = ["Date", "Start", "End", "Miles", "Purpose", "Deduction"]
            let colWidths: [CGFloat] = [90, 60, 60, 50, 180, 72]
            var xPos = margin
            for (i, header) in headers.enumerated() {
                header.draw(at: CGPoint(x: xPos, y: yPosition), withAttributes: [.font: boldFont])
                xPos += colWidths[i]
            }
            yPosition += 18
            
            // Entries
            var totalMiles: Double = 0
            var totalDeduction: Double = 0
            
            for entry in entries.sorted(by: { $0.date < $1.date }) {
                if yPosition > pageHeight - 80 {
                    context.beginPage()
                    yPosition = margin
                }
                
                xPos = margin
                let values = [
                    entry.dateString,
                    String(format: "%.0f", entry.startOdometer),
                    String(format: "%.0f", entry.endOdometer),
                    String(format: "%.1f", entry.miles),
                    entry.purpose,
                    String(format: "$%.2f", entry.deductionAmount)
                ]
                for (i, val) in values.enumerated() {
                    val.draw(at: CGPoint(x: xPos, y: yPosition), withAttributes: [.font: bodyFont])
                    xPos += colWidths[i]
                }
                totalMiles += entry.miles
                totalDeduction += entry.deductionAmount
                yPosition += 16
            }
            
            // Totals
            yPosition += 10
            let totalLine = UIBezierPath()
            totalLine.move(to: CGPoint(x: margin, y: yPosition))
            totalLine.addLine(to: CGPoint(x: margin + contentWidth, y: yPosition))
            UIColor.black.setStroke()
            totalLine.lineWidth = 1
            totalLine.stroke()
            yPosition += 8
            
            "TOTALS".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: [.font: boldFont])
            String(format: "%.1f mi", totalMiles).draw(at: CGPoint(x: margin + 210, y: yPosition), withAttributes: [.font: boldFont])
            String(format: "$%.2f", totalDeduction).draw(at: CGPoint(x: margin + 440, y: yPosition), withAttributes: [.font: boldFont])
            yPosition += 20
            
            let rateNote = "IRS Standard Mileage Rate: $\(String(format: "%.2f", MileageEntry.irsRate))/mile"
            rateNote.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: [
                .font: UIFont.italicSystemFont(ofSize: 10), .foregroundColor: UIColor.gray
            ])
        }
        
        return data
    }
    
    // MARK: - Shift Report
    static func generateShiftReport(shifts: [Shift], dateRange: String) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: UIGraphicsPDFRendererFormat()
        )
        
        let data = renderer.pdfData { context in
            context.beginPage()
            var yPosition: CGFloat = margin
            
            let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
            let bodyFont = UIFont.systemFont(ofSize: 11, weight: .regular)
            let boldFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
            
            "Shift Report — \(dateRange)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: [
                .font: titleFont, .foregroundColor: UIColor(red: 0.17, green: 0.37, blue: 0.54, alpha: 1.0)
            ])
            yPosition += 35
            
            let headers = ["Date", "Patient", "Time In", "Time Out", "Hours", "Notes"]
            let colWidths: [CGFloat] = [90, 80, 70, 70, 55, 147]
            var xPos = margin
            for (i, header) in headers.enumerated() {
                header.draw(at: CGPoint(x: xPos, y: yPosition), withAttributes: [.font: boldFont])
                xPos += colWidths[i]
            }
            yPosition += 18
            
            var totalHours: Double = 0
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            
            for shift in shifts.sorted(by: { $0.startTime < $1.startTime }) {
                if yPosition > pageHeight - 80 {
                    context.beginPage()
                    yPosition = margin
                }
                
                xPos = margin
                let values = [
                    dateFormatter.string(from: shift.startTime),
                    shift.patient?.firstName ?? "—",
                    timeFormatter.string(from: shift.startTime),
                    shift.endTime.map { timeFormatter.string(from: $0) } ?? "Active",
                    String(format: "%.1f", shift.durationDecimalHours),
                    shift.notes
                ]
                for (i, val) in values.enumerated() {
                    val.draw(at: CGPoint(x: xPos, y: yPosition), withAttributes: [.font: bodyFont])
                    xPos += colWidths[i]
                }
                totalHours += shift.durationDecimalHours
                yPosition += 16
            }
            
            yPosition += 10
            "Total Hours: \(String(format: "%.1f", totalHours))".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: [.font: boldFont])
        }
        
        return data
    }
}
