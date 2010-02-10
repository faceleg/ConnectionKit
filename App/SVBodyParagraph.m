// 
//  SVParagraph.m
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyParagraph.h"
#import "SVBodyParagraphDOMAdapter.h"

#import "SVParagraphLink.h"
#import "SVTitleBoxHTMLContext.h"
#import "SVPlugInPagelet.h"

#import "NSSet+Karelia.h"
#import "NSString+Karelia.h"

#import "SVBlogSummaryDOMController.h"


@implementation SVBodyParagraph 

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    [self setPrimitiveValue:@"" forKey:@"archiveString"];
}

#pragma mark HTML

- (void)writeHTML;
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    [context writeStartTag:@"P"
                    idName:([context isEditable] ? [self editingElementID] : nil)
                 className:nil];
    
    [self writeInnerHTML];
    
    [context writeEndTag];
}

- (void)writeInnerHTML;
{
    //  The inner HTML is made up by combining our archive string, links, and inline graphics. Do this by writing a chunk of archive string, followed by link/graphic tag, and so on.
    
    SVHTMLContext *context = [SVHTMLContext currentContext];
    NSString *archive = [self archiveString];
    NSArray *links = [self orderedAttributes];
    
    for (SVParagraphLink *aLink in links)
    {
        [context writeStartTag:@"a" idName:nil className:nil];
        [context writeEndTag];
    }
    
    // I don't like the if statement here, as ideally archive is never nil. However, after undoin a change, it sometimes is :( — Mike
    if (archive) [context writeHTMLString:archive];
}

- (DOMHTMLElement *)elementForEditingInDOMDocument:(DOMDocument *)document
{
    // Want to make sure it's also got the right tagname
    DOMHTMLElement *result = [super elementForEditingInDOMDocument:document];
    
    if (![[result tagName] isEqualToString:@"P"]) result = nil;
    
    return result;
}

- (Class)DOMControllerClass;
{
    return [SVBodyParagraphDOMAdapter class];		// we can temporarily try SVBlogSummaryDOMController
}

- (void)readHTMLFromElement:(DOMHTMLElement *)element;
{
    // Easiest way to archive string, is to use a context – see, they do all sorts!
    SVMutableStringHTMLContext *context = [[SVTitleBoxHTMLContext alloc] initWithParagraph:self];
    [element writeInnerHTMLToContext:context];
    
    NSString *string = [context markupString];
    [self setArchiveString:string];
    
    [context release];
}

#pragma mark Raw Properties

@dynamic archiveString;

#pragma mark  Attributes

@dynamic attributes;

- (NSArray *)orderedAttributes;
{
    // Build sort descriptors if needed
    static NSArray *sortDescriptors;
    if (!sortDescriptors)
    {
        // Links should never overlap, but they can theoretically be stacked inside one another. Therefore sort by location first, and length next
        NSSortDescriptor *locationSorting = [[NSSortDescriptor alloc] initWithKey:@"location"
                                                                        ascending:YES];
        NSSortDescriptor *lengthSorting = [[NSSortDescriptor alloc] initWithKey:@"length"
                                                                      ascending:NO];
        
        sortDescriptors = [[NSArray alloc] initWithObjects:locationSorting, lengthSorting, nil];
        [locationSorting release];
        [lengthSorting release];
    }
    
    
    // Fetch and sort our links
    NSArray *result = [[self attributes] KS_sortedArrayUsingDescriptors:sortDescriptors];
    return result;
}

@end
