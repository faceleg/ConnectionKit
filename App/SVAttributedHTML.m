//
//  SVAttributedHTML.m
//  Sandvox
//
//  Created by Mike on 20/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVAttributedHTML.h"

#import "SVGraphic.h"
#import "SVHTMLContext.h"
#import "SVTextAttachment.h"

#import "NSManagedObject+KTExtensions.h"

#import "NSString+Karelia.h"


@implementation NSAttributedString (SVAttributedHTML)

#pragma mark Pasteboard

- (void)attributedHTMLStringWriteToPasteboard:(NSPasteboard *)pasteboard;
{
    // Create a clone where SVTextAttachment is replaced by its serialized form
    NSMutableAttributedString *archivableAttributedString = [self mutableCopy];
    
    NSRange range = NSMakeRange(0, [archivableAttributedString length]);
    NSUInteger location = 0;
    
    while (location < range.length)
    {
        NSRange effectiveRange;
        SVGraphic *graphic = [archivableAttributedString attribute:@"SVAttachment"
                                                              atIndex:location
                                                longestEffectiveRange:&effectiveRange
                                                              inRange:range];
        
        NSMutableDictionary *plist = [[NSMutableDictionary alloc] init];
        
        SVTextAttachment *textAttachment = [graphic textAttachment];
        if (textAttachment)
        {
            // Replace the attachment. Ignore range as it's not relevant any more
            [textAttachment populateSerializedProperties:plist];
            [plist removeObjectForKey:@"location"];
            [plist removeObjectForKey:@"length"];
        }
        else if (graphic)
        {
            // Fake the attachment
            [plist setObject:[graphic serializedProperties] forKey:@"graphic"];
        }
        
        
        [archivableAttributedString removeAttribute:@"SVAttachment"
                                              range:effectiveRange];
        
        [archivableAttributedString addAttribute:@"Serialized SVAttachment"
                                           value:plist
                                           range:effectiveRange];
        [plist release];
        
        
        // Advance the search
        location = location + effectiveRange.length;
    }
    
    
    // Write to the pboard in archive form
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:archivableAttributedString];
    [pasteboard setData:data forType:@"com.karelia.html+graphics"];
    [archivableAttributedString release];
}

+ (NSAttributedString *)attributedHTMLFromPasteboard:(NSPasteboard *)pasteboard;
{
    NSData *data = [pasteboard dataForType:@"com.karelia.html+graphics"];
    if (!data) return nil;
    
    
    NSAttributedString *result = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    return result;
}

+ (NSAttributedString *)attributedHTMLStringFromPasteboard:(NSPasteboard *)pasteboard
                                insertAttachmentsIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    NSAttributedString *archivedAttributedString =
    [self attributedHTMLFromPasteboard:pasteboard];
    if (!archivedAttributedString) return nil;
    
    NSMutableAttributedString *result = [[archivedAttributedString mutableCopy] autorelease];
    
    
    // Create attachment objects for each serialized one
    NSRange range = NSMakeRange(0, [result length]);
    NSUInteger location = 0;
    
    while (location < range.length)
    {
        NSRange effectiveRange;
        id serializedProperties = [result attribute:@"Serialized SVAttachment"
                                            atIndex:location
                              longestEffectiveRange:&effectiveRange
                                            inRange:range];
        
        if (serializedProperties)
        {
            // Replace the attachment
            SVTextAttachment *attachment = [NSEntityDescription
                                            insertNewObjectForEntityForName:@"TextAttachment"
                                            inManagedObjectContext:context];
            [attachment awakeFromPropertyList:serializedProperties];
            
            [result removeAttribute:@"Serialized SVAttachment"
                              range:effectiveRange];
            
            [result addAttribute:@"SVAttachment"
                           value:[attachment graphic]
                           range:effectiveRange];
        }
        
        // Advance the search
        location = location + effectiveRange.length;
    }
    
    
    return result;
}

+ (NSArray *)pageletsFromPasteboard:(NSPasteboard *)pasteboard
     insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    NSMutableArray *result = [NSMutableArray array];
    NSAttributedString *archive = [self attributedHTMLFromPasteboard:pasteboard];
    
    
    // Create attachment objects for each serialized one
    NSRange range = NSMakeRange(0, [archive length]);
    NSUInteger location = 0;
    
    while (location < range.length)
    {
        NSRange effectiveRange;
        id serializedProperties = [archive attribute:@"Serialized SVAttachment"
                                             atIndex:location
                               longestEffectiveRange:&effectiveRange
                                             inRange:range];
        
        if (serializedProperties)
        {
            // Replace the attachment
            id serializedGraphic = [serializedProperties valueForKey:@"graphic"];
            
            SVGraphic *graphic = [SVGraphic graphicWithSerializedProperties:serializedGraphic
                                             insertIntoManagedObjectContext:context];
            
            [result addObject:graphic];
        }
        
        // Advance the search
        location = location + effectiveRange.length;
    }
    
    
    return result;
}

+ (NSArray *)attributedHTMStringPasteboardTypes;
{
    return [NSArray arrayWithObject:@"com.karelia.html+graphics"];
}

#pragma mark Convenience

+ (NSAttributedString *)attributedHTMLStringWithAttachment:(id)attachment;
{
    NSAttributedString *result = [[NSAttributedString alloc]
      initWithString:[NSString stringWithUnichar:NSAttachmentCharacter]
      attributes:[NSDictionary dictionaryWithObject:attachment forKey:@"SVAttachment"]];
                                  
    return [result autorelease];
}

+ (NSAttributedString *)calloutAttributedHTMLStringWithGraphic:(SVGraphic *)graphic;
{
    OBPRECONDITION(graphic);
    
    // Create attachment for the graphic
    SVTextAttachment *textAttachment = [NSEntityDescription
                                        insertNewObjectForEntityForName:@"TextAttachment"
                                        inManagedObjectContext:[graphic managedObjectContext]];
    [textAttachment setGraphic:graphic];
    //[textAttachment setBody:text];
    [textAttachment setPlacement:[NSNumber numberWithInteger:SVGraphicPlacementCallout]];
    
    
    // Finish up
    return [self attributedHTMLStringWithAttachment:textAttachment];
}

@end
