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


@implementation SVAttributedHTML

#pragma mark Init & Dealloc

- (id)init;
{
    [super init];
    _storage = [[NSMutableAttributedString alloc] init];
    return self;
}

- (id)initWithString:(NSString *)str;
{
    [super init];
    _storage = [[NSMutableAttributedString alloc] initWithString:str];
    return self;
}

- (void)dealloc
{
    [_storage release];
    [super dealloc];
}

#pragma mark Primitives

- (NSString *)string { return [_storage string]; }

- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range;
{
    return [_storage attributesAtIndex:location effectiveRange:range];
}

- (void)replaceCharactersInRange:(NSRange)aRange withString:(NSString *)aString
{
    [_storage replaceCharactersInRange:aRange withString:aString];
}

- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)aRange
{
    [_storage setAttributes:attributes range:aRange];
}

#pragma mark Pasteboard

+ (SVAttributedHTML *)attributedHTMLFromPasteboard:(NSPasteboard *)pasteboard
                              managedObjectContext:(NSManagedObjectContext *)context;
{
    NSDictionary *plist = [pasteboard propertyListForType:@"com.karelia.html+graphics"];
    if (!plist) return nil;
    
    
    SVAttributedHTML *result = [[self alloc] initWithString:[plist objectForKey:@"HTMLString"]];
    
    
    // Create attachment objects for each serialized one
    NSArray *attachments = [plist objectForKey:@"attachments"];
    for (NSDictionary *aSerializedAttachment in attachments)
    {
        SVTextAttachment *attachment = [NSEntityDescription
                                        insertNewObjectForEntityForName:@"TextAttachment"
                                        inManagedObjectContext:context];
        [attachment awakeFromPropertyList:aSerializedAttachment];
        
        [result addAttribute:@"SVAttachment"
                       value:attachment
                       range:[attachment range]];
    }
    
    
    return result;
}

#pragma mark Output

- (void)writeHTMLToContext:(SVHTMLContext *)context;
{
    //  Pretty similar to -[SVRichText richText]. Perhaps we can merge the two eventually?
    
    
    [context push];
    
    
    NSRange range = NSMakeRange(0, [self length]);
    NSUInteger location = 0;
    
    while (location < range.length)
    {
        NSRange effectiveRange;
        SVTextAttachment *attachment = [self attribute:@"SVAttachment"
                                               atIndex:location
                                 longestEffectiveRange:&effectiveRange
                                               inRange:range];
        
        if (attachment)
        {
            // Write the graphic
            [[attachment graphic] writeHTML];
        }
        else
        {
            NSString *html = [[self string] substringWithRange:effectiveRange];
            [context writeHTMLString:html];
        }
        
        // Advance the search
        location = location + effectiveRange.length;
    }
    
    
    [context pop];
}

@end
