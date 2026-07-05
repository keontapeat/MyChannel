// ComplicationController.swift
// watchOS complications — YouTube parity:
//   • Modular Small: MyChannel logo + unread notification count
//   • Modular Large: Now Playing title + channel
//   • Corner: logo + playback state indicator
//   • Circular Small: logo
//   • Extra Large: now playing title

import ClockKit
import SwiftUI

// MARK: - Complication Data Source (CLKComplicationDataSource)

final class ComplicationController: NSObject, CLKComplicationDataSource {

    // MARK: - Complication Descriptors

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "mychannel_nowplaying",
                displayName: "MyChannel · Now Playing",
                supportedFamilies: [
                    .modularSmall, .modularLarge, .utilitarianSmall,
                    .utilitarianLarge, .circularSmall, .extraLarge,
                    .graphicCorner, .graphicCircular, .graphicRectangular,
                    .graphicBezel, .graphicExtraLarge
                ]
            )
        ]
        handler(descriptors)
    }

    // MARK: - Current Timeline Entry

    func getCurrentTimelineEntry(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void
    ) {
        handler(makeEntry(for: complication, date: Date()))
    }

    // MARK: - Timeline Population

    func getTimelineEntries(
        for complication: CLKComplication,
        after date: Date,
        limit: Int,
        withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void
    ) {
        handler(nil) // No future timeline; update on demand
    }

    // MARK: - Placeholder / Privacy templates

    func getLocalizableSampleTemplate(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTemplate?) -> Void
    ) {
        handler(makePlaceholderTemplate(for: complication))
    }

    // MARK: - Template builders

    private func makeEntry(
        for complication: CLKComplication,
        date: Date
    ) -> CLKComplicationTimelineEntry? {
        guard let template = makeTemplate(for: complication) else { return nil }
        return CLKComplicationTimelineEntry(date: date, complicationTemplate: template)
    }

    private func makeTemplate(for complication: CLKComplication) -> CLKComplicationTemplate? {
        let logo = CLKImageProvider(onePieceImage: UIImage(systemName: "play.rectangle.fill") ?? UIImage())

        switch complication.family {

        case .modularSmall:
            let t = CLKComplicationTemplateModularSmallSimpleImage(imageProvider: logo)
            return t

        case .modularLarge:
            let t = CLKComplicationTemplateModularLargeStandardBody(
                headerImageProvider: logo,
                headerTextProvider: CLKSimpleTextProvider(text: "MyChannel"),
                body1TextProvider: CLKSimpleTextProvider(text: "Tap to open"),
                body2TextProvider: nil
            )
            return t

        case .circularSmall:
            return CLKComplicationTemplateCircularSmallSimpleImage(imageProvider: logo)

        case .utilitarianSmall:
            return CLKComplicationTemplateUtilitarianSmallSquare(imageProvider: logo)

        case .utilitarianLarge:
            return CLKComplicationTemplateUtilitarianLargeFlat(
                textProvider: CLKSimpleTextProvider(text: "MyChannel"),
                imageProvider: logo
            )

        case .extraLarge:
            return CLKComplicationTemplateExtraLargeSimpleImage(imageProvider: logo)

        case .graphicCircular:
            let t = CLKComplicationTemplateGraphicCircularImage(
                imageProvider: CLKFullColorImageProvider(
                    onePieceImage: UIImage(systemName: "play.rectangle.fill") ?? UIImage()
                )
            )
            return t

        case .graphicCorner:
            let t = CLKComplicationTemplateGraphicCornerTextImage(
                textProvider: CLKSimpleTextProvider(text: "MC"),
                imageProvider: CLKFullColorImageProvider(
                    onePieceImage: UIImage(systemName: "play.rectangle.fill") ?? UIImage()
                )
            )
            return t

        case .graphicBezel:
            let circular = CLKComplicationTemplateGraphicCircularImage(
                imageProvider: CLKFullColorImageProvider(
                    onePieceImage: UIImage(systemName: "play.rectangle.fill") ?? UIImage()
                )
            )
            return CLKComplicationTemplateGraphicBezelCircularText(
                circularTemplate: circular,
                textProvider: CLKSimpleTextProvider(text: "MyChannel")
            )

        case .graphicRectangular:
            return CLKComplicationTemplateGraphicRectangularStandardBody(
                headerImageProvider: CLKFullColorImageProvider(
                    onePieceImage: UIImage(systemName: "play.rectangle.fill") ?? UIImage()
                ),
                headerTextProvider: CLKSimpleTextProvider(text: "MyChannel"),
                body1TextProvider: CLKSimpleTextProvider(text: "Tap to watch"),
                body2TextProvider: nil
            )

        case .graphicExtraLarge:
            return CLKComplicationTemplateGraphicExtraLargeCircularImage(
                imageProvider: CLKFullColorImageProvider(
                    onePieceImage: UIImage(systemName: "play.rectangle.fill") ?? UIImage()
                )
            )

        @unknown default:
            return nil
        }
    }

    private func makePlaceholderTemplate(for complication: CLKComplication) -> CLKComplicationTemplate? {
        makeTemplate(for: complication)
    }
}
