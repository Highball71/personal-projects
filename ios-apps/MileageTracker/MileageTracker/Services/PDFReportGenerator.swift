import UIKit

/// Generates IRS-compliant mileage reports as PDF documents.
/// Reports include trip-by-trip detail with dates, locations, odometer readings,
/// purposes, and deduction amounts, plus summary totals.
enum PDFReportGenerator {
    // MARK: - Public API

    /// Generate a quarterly or annual mileage report.
    static func generateReport(
        trips: [Trip],
        title: String,
        dateRange: String,
        irsRate: Double,
        odometerStart: Double? = nil,
        odometerEnd: Double? = nil
    ) -> Data {
        let pageSize = CGSize(width: 612, height: 792) // US Letter
        let margin: CGFloat = 40
        let contentWidth = pageSize.width - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        return renderer.pdfData { context in
            var y: CGFloat = 0

            func newPage() {
                context.beginPage()
                y = margin
            }

            func checkPageBreak(needed: CGFloat) {
                if y + needed > pageSize.height - margin {
                    newPage()
                }
            }

            // -- Page 1 --
            newPage()

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.systemBlue,
            ]
            let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
            titleStr.draw(at: CGPoint(x: margin, y: y))
            y += 28

            // Date range
            let rangeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray,
            ]
            let rangeStr = NSAttributedString(string: dateRange, attributes: rangeAttrs)
            rangeStr.draw(at: CGPoint(x: margin, y: y))
            y += 20

            // IRS rate note
            let rateStr = NSAttributedString(
                string: String(format: "IRS Standard Mileage Rate: $%.3f/mile", irsRate),
                attributes: rangeAttrs
            )
            rateStr.draw(at: CGPoint(x: margin, y: y))
            y += 24

            // Odometer readings if provided
            if let start = odometerStart, let end = odometerEnd {
                let odoStr = NSAttributedString(
                    string: String(format: "Odometer: %.0f (start) → %.0f (end) = %.0f total miles", start, end, end - start),
                    attributes: rangeAttrs
                )
                odoStr.draw(at: CGPoint(x: margin, y: y))
                y += 24
            }

            // Separator line
            drawLine(context: context.cgContext, y: y, margin: margin, width: contentWidth)
            y += 12

            // -- Summary Section --
            let businessTrips = trips.filter { $0.isBusiness }
            let personalTrips = trips.filter { !$0.isBusiness }
            let totalBusinessMiles = businessTrips.reduce(0.0) { $0 + $1.miles }
            let totalPersonalMiles = personalTrips.reduce(0.0) { $0 + $1.miles }
            let totalMiles = totalBusinessMiles + totalPersonalMiles
            let businessPercent = totalMiles > 0 ? (totalBusinessMiles / totalMiles * 100) : 0
            let totalDeduction = totalBusinessMiles * irsRate
            let totalTolls = businessTrips.reduce(0.0) { $0 + $1.tollAmount }
            let totalParking = businessTrips.reduce(0.0) { $0 + $1.parkingAmount }

            let boldAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11),
            ]
            let summaryLines = [
                String(format: "Total Business Miles: %.1f", totalBusinessMiles),
                String(format: "Total Personal Miles: %.1f", totalPersonalMiles),
                String(format: "Business Use Percentage: %.1f%%", businessPercent),
                String(format: "Mileage Deduction: $%.2f", totalDeduction),
                String(format: "Tolls: $%.2f  |  Parking: $%.2f", totalTolls, totalParking),
                String(format: "Total Deductible: $%.2f", totalDeduction + totalTolls + totalParking),
            ]

            for line in summaryLines {
                let str = NSAttributedString(string: line, attributes: boldAttrs)
                str.draw(at: CGPoint(x: margin, y: y))
                y += 16
            }
            y += 12

            drawLine(context: context.cgContext, y: y, margin: margin, width: contentWidth)
            y += 16

            // -- Trip Detail Header --
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 9),
                .foregroundColor: UIColor.darkGray,
            ]

            let columns: [(String, CGFloat, CGFloat)] = [
                ("DATE", margin, 65),
                ("FROM", margin + 65, 80),
                ("TO", margin + 145, 80),
                ("START", margin + 225, 45),
                ("END", margin + 270, 45),
                ("MILES", margin + 315, 40),
                ("PURPOSE", margin + 355, 130),
                ("DEDUCTION", margin + 485, 70),
            ]

            for (header, x, width) in columns {
                let str = NSAttributedString(string: header, attributes: headerAttrs)
                str.draw(in: CGRect(x: x, y: y, width: width, height: 14))
            }
            y += 16

            // -- Trip Rows --
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
            ]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "M/d/yy"

            let sortedTrips = trips.sorted { $0.date < $1.date }

            for trip in sortedTrips {
                checkPageBreak(needed: 14)

                let rowData: [(String, CGFloat, CGFloat)] = [
                    (dateFormatter.string(from: trip.date), margin, 65),
                    (trip.startLocationName, margin + 65, 80),
                    (trip.endLocationName, margin + 145, 80),
                    (String(format: "%.0f", trip.startOdometer), margin + 225, 45),
                    (String(format: "%.0f", trip.endOdometer), margin + 270, 45),
                    (String(format: "%.1f", trip.miles), margin + 315, 40),
                    (trip.businessPurpose, margin + 355, 130),
                    (trip.isBusiness ? String(format: "$%.2f", trip.deduction(at: irsRate)) : "—", margin + 485, 70),
                ]

                for (text, x, width) in rowData {
                    let str = NSAttributedString(string: text, attributes: rowAttrs)
                    str.draw(in: CGRect(x: x, y: y, width: width, height: 12))
                }
                y += 13
            }

            // -- Footer totals --
            y += 8
            checkPageBreak(needed: 30)
            drawLine(context: context.cgContext, y: y, margin: margin, width: contentWidth)
            y += 8

            let totalStr = NSAttributedString(
                string: String(format: "TOTALS: %.1f business miles  |  Deduction: $%.2f  |  Tolls: $%.2f  |  Parking: $%.2f",
                               totalBusinessMiles, totalDeduction, totalTolls, totalParking),
                attributes: boldAttrs
            )
            totalStr.draw(at: CGPoint(x: margin, y: y))
        }
    }

    // MARK: - Helpers

    private static func drawLine(context: CGContext, y: CGFloat, margin: CGFloat, width: CGFloat) {
        context.setStrokeColor(UIColor.separator.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: margin + width, y: y))
        context.strokePath()
    }
}
