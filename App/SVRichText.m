// 
//  SVPageletBody.m
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVRichText.h"

#import "SVHTMLTemplateParser.h"
#import "SVMediaGraphic.h"
#import "KTPage.h"
#import "SVGraphicContainer.h"
#import "SVRichTextDOMController.h"
#import "SVTextAttachment.h"

#import "NSArray+Karelia.h"
#import "NSError+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSSortDescriptor+Karelia.h"
#import "NSString+Karelia.h"
#import "KSStringHTMLEntityUnescaping.h"


@interface SVRichText ()
@property(nonatomic, copy, readwrite) NSSet *attachments;
@end


@interface SVRichText (CoreDataGenerated)
- (void)addAttachmentsObject:(SVTextAttachment *)attachment;
@end


#pragma mark -


@implementation SVRichText 

#pragma mark Init

+ (SVRichText *)insertPageletBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    return [NSEntityDescription insertNewObjectForEntityForName:@"TextBoxBody"
                                         inManagedObjectContext:context];
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    // Should we take the opportinity to create a starter paragraph?
}

#pragma mark Text

- (NSAttributedString *)attributedHTMLString;
{
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc]
                                         initWithString:[self string]];
    
    for (SVTextAttachment *anAttachment in [self attachments])
    {
        NSRange range = [anAttachment range];
        if (range.length == 32767)   // signifies a 1.5 embedded image that hasn't been imported yet
        {
            // Search for such an image
            NSString *identifier = [[anAttachment graphic] valueForKey:@"identifier"];
            NSString *searchString = [NSString stringWithFormat:@"/%@\"", identifier];
            
            NSRange idRange = [[result string] rangeOfString:searchString];
            
            range = [[result string] rangeOfString:@"<img "
                                           options:NSBackwardsSearch
                                             range:NSMakeRange(0, idRange.location)];
            
            idRange = [[result string] rangeOfString:@">"
                                             options:0
                                               range:NSMakeRange(idRange.location, [result length] - idRange.location)];
            
            range.length = idRange.location - range.location + idRange.length;
        }
        
        
        if (range.length)
        {
            if (range.location < [result length])
            {
                if ((range.location + range.length) > [result length])
                {
                    range.length = [result length] - range.location;
                    NSLog(@"Reigned in attachment that exceeded HTML: %@ %@ %@", anAttachment, [anAttachment graphic], [result string]);
                }
                
                [result addAttribute:@"SVAttachment"
                               value:anAttachment
                               range:range];
            }
            else
            {
                NSLog(@"Attachment past end of HTML: %@ %@ %@", anAttachment, [anAttachment graphic], [result string]);
            }
        }
        else
        {
            NSLog(@"Zero length attachment: %@ %@ %@", anAttachment, [anAttachment graphic], [result string]);
        }
        
        
        // Imported text doesn't use NSAttachmentCharacter, so we have to sub it in
        if (range.length > 1)
        {
            NSString *string = [@""
                                stringByPaddingToLength:range.length
                                withString:[NSString stringWithUnichar:NSAttachmentCharacter]
                                startingAtIndex:0];
            
            [result replaceCharactersInRange:range withString:string];
        }
        
        /*else
        {
             
            
            NSMutableArray *embeddedImages = [result attribute:@"KTEmbeddedImages"
                                                       atIndex:0
                                                effectiveRange:NULL];
            if (!embeddedImages)
            {
                embeddedImages = [[NSMutableArray alloc] init];
                
                [result addAttribute:@"KTEmbeddedImages"
                               value:embeddedImages
                               range:NSMakeRange(0, [result length])];
                
                [embeddedImages release];
            }
            
            [embeddedImages addObject:anAttachment];
        }*/
    }
    
    return [result autorelease];
}

- (void)setAttributedHTMLString:(NSAttributedString *)attributedHTML;
{
    [self setAttributedHTMLString:attributedHTML wasModified:YES];
}

- (void)setAttributedHTMLString:(NSAttributedString *)attributedHTML wasModified:(BOOL)modified;
{
    NSMutableSet *attachments = [[NSMutableSet alloc] init];
    
    NSUInteger index = 0;
    while (index < [attributedHTML length])
    {
        NSRange range;
        SVTextAttachment *anAttachment = [attributedHTML attribute:@"SVAttachment"
                                                           atIndex:index
                                                    effectiveRange:&range];
        
        if (anAttachment)
        {
            [anAttachment setRange:range];  // may not be correct, so need to update here
            [attachments addObject:anAttachment];
        }
        
        index = range.location + range.length;
    }
    
    [self setString:[attributedHTML string] attachments:attachments wasModified:modified];
    [attachments release];
}

@dynamic string;

- (void)setString:(NSString *)string attachments:(NSSet *)attachments;
{
    [self setString:string attachments:attachments wasModified:YES];
}

- (void)setString:(NSString *)string attachments:(NSSet *)attachments wasModified:(BOOL)modified;
{
    [self setString:string];
    
    NSMutableSet *removedAttachments = [[self attachments] mutableCopy];
    [removedAttachments minusSet:attachments];
    [self setAttachments:attachments];
    
    for (SVTextAttachment *anAttachment in removedAttachments)
    {
        [[self managedObjectContext] deleteObject:anAttachment];
    }
    [removedAttachments release];
}

@dynamic attachments;

- (NSArray *)orderedAttachments;
{
    NSArray *attachments = [[self attachments] KS_sortedArrayUsingDescriptors:
                            [[self class] attachmentSortDescriptors]];
    
    return attachments;
}

- (BOOL)endsOnAttachment;
{
    BOOL result = NO;
    
    NSAttributedString *attributedHTML = [self attributedHTMLString];
    if ([attributedHTML length])
    {
        result = ([attributedHTML attribute:@"SVAttachment"
                                        atIndex:([attributedHTML length] - 1)
                                effectiveRange:NULL] != nil);
    }
    
    return result;
}

+ (NSArray *)attachmentSortDescriptors;
{
    return [NSSortDescriptor sortDescriptorArrayWithKey:@"location"
                                              ascending:YES];
}

- (BOOL)isEmpty;
{
    NSString *text = [[self string] stringByConvertingHTMLToPlainText];
    BOOL result = ([text length] == 0 || [text isEqualToString:@"\n"]);
    return result;
}

- (void)deleteCharactersInRange:(NSRange)range;
{
    // Delete the characters
    NSMutableString *string = [[self string] mutableCopy];
    [string deleteCharactersInRange:range];
    [self setString:string];
    
    
    // Knock down all attachment ranges. Delete any attachments within the range
    NSEnumerator *attachmentsEnumerator = [[self orderedAttachments] reverseObjectEnumerator];
    SVTextAttachment *anAttachment;
    while (anAttachment = [attachmentsEnumerator nextObject])
    {
        // An attachment after the range can be just bumped down
        NSRange aRange = [anAttachment range];
        if (aRange.location >= (range.location + range.length))
        {
            [anAttachment setLocation:[NSNumber numberWithUnsignedInteger:(aRange.location - range.length)]];
        }
        
        // An attachment in the range should be deleted
        else if (aRange.location >= range.location)
        {
            [[self managedObjectContext] deleteObject:anAttachment];
        }
        
        // Once we hit before the range no more work to do
        else
        {
            break;
        }
    }
}

#pragma mark HTML

- (void)writeText:(SVHTMLContext *)context;
{
    NSRange range = NSMakeRange(0, [[self string] length]);
    [self writeText:context range:range];
}

- (void)writeText:(SVHTMLContext *)context range:(NSRange)searchRange;
{
    NSAttributedString *html = [[self attributedHTMLString] attributedSubstringFromRange:searchRange];
    
    
    
    [context writeAttributedHTMLString:html];
    
    //[context addDependencyOnObject:self keyPath:@"string"];
    // Don't register this dependency as SVRichTextDOMController will handle its own dependencies
}

- (void)writeText; { [self writeText:[[SVHTMLTemplateParser currentTemplateParser] HTMLContext]]; }

- (void)write:(SVHTMLContext *)context graphic:(id <SVGraphic>)graphic;
{
    SVInlineGraphicContainer *container = [[SVInlineGraphicContainer alloc] initWithGraphic:graphic]; // yes, fake it!
    [context beginGraphicContainer:container];
    [container release];
    
    @try
    {
        if ([graphic shouldWriteHTMLInline])
        {
            return [context writeGraphic:graphic];
        }
        
        
        // Indexes want <H3>s
        NSUInteger level = [context currentHeaderLevel];
        [context setCurrentHeaderLevel:2];
        @try
        {
            // Register dependencies that come into play regardless of the route writing takes
            [context addDependencyOnObject:graphic keyPath:@"showsCaption"];
            
            // <div class="graphic-container center">
            [(SVGraphic *)graphic buildClassName:context includeWrap:YES];
            [context startElement:@"div"];
            
            
            // <div class="graphic"> or <img class="graphic">
            [context pushClassName:@"graphic"];
            
            NSString *className = [(SVGraphic *)graphic inlineGraphicClassName];
            if (className) [context pushClassName:className];
            
            if (![graphic isExplicitlySized:context])
            {
                NSNumber *width = [graphic containerWidth];
                if (width)
                {
                    NSString *style = [NSString stringWithFormat:@"width:%upx", [width unsignedIntValue]];
                    [context pushAttribute:@"style" value:style];
                }
            }
            
            
            [context writeGraphic:graphic];
            
            
            // Caption if requested
            id <SVGraphic> caption = [graphic captionGraphic];
            if (caption) // was registered as dependency at start of if block
            {
                [context writeGraphic:caption];
            }
            
            
            // Finish up
            [context endElement];
        }
        @finally
        {
            [context setCurrentHeaderLevel:level];
        }
    }
    @finally
    {
        [context endGraphicContainer];
    }
}

#pragma mark Validation

- (BOOL)validateAttachments:(NSSet **)attachments error:(NSError **)error;
{
    BOOL result = YES;
    
    for (SVTextAttachment *anAttachment in *attachments)
    {
        result = [self validateAttachment:anAttachment
                                placement:[[anAttachment placement] integerValue]
                                    error:error];
        if (!result) break;
    }
    
    return result;
}

- (BOOL)validateAttachment:(SVTextAttachment *)attachment
                 placement:(SVGraphicPlacement)placement
                     error:(NSError **)error;
{
    // Base class can only handle inline graphic
    if (placement != SVGraphicPlacementInline)
    {
        if (error) *error = [KSError validationErrorWithCode:NSValidationNumberTooLargeError
                                                      object:self
                                                         key:nil
                                                       value:nil
                                  localizedDescriptionFormat:@"Rich text areas only support inline graphics"];
        
        return NO;
    }
    
    return YES;
}

- (BOOL)attachmentsMustBeWrittenInline; { return YES; }

- (CGFloat)maxGraphicWidth;
{
    return 200.0f;
}

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    [propertyList setValue:[[[self attachments] allObjects] valueForKey:@"serializedProperties"]
                    forKey:@"attachments"];
}

- (void)awakeFromPropertyList:(id)propertyList;
{
    [super awakeFromPropertyList:propertyList];
    
    NSArray *attachments = [propertyList objectForKey:@"attachments"];
    if (attachments)
    {
        for (id aSerializedAttachment in attachments)
        {
            SVTextAttachment *attachment = [SVTextAttachment insertNewTextAttachmentInManagedObjectContext:[self managedObjectContext]];
            [attachment awakeFromPropertyList:aSerializedAttachment];
            [self addAttachmentsObject:attachment];
        }
    }
}

- (SVDOMController *)newDOMControllerWithElementIdName:(NSString *)elementID node:(DOMNode *)node;
{
    SVDOMController *result = [[SVDOMController alloc] initWithElementIdName:elementID ancestorNode:node];
    [result setRepresentedObject:self];
    return result;
}

@end
