// 
//  SVParagraph.m
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyParagraph.h"
#import "SVBodyParagraphDOMAdapter.h"

#import "SVLink.h"
#import "SVPlugInGraphic.h"
#import "SVHTMLContext.h"

#import "NSSet+Karelia.h"
#import "NSString+Karelia.h"


@implementation SVBodyParagraph 

#pragma mark HTML

- (void)writeHTML;
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    [context writeStartTag:[self tagName]
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
    NSArray *links = [self orderedLinks];
    
    for (SVLink *aLink in links)
    {
        [context writeStartTag:@"a" idName:nil className:nil];
        [context writeEndTag];
    }
    
    [context writeHTMLString:archive];
}

- (DOMHTMLElement *)elementForEditingInDOMDocument:(DOMDocument *)document
{
    // Want to make sure it's also got the right tagname
    DOMHTMLElement *result = [super elementForEditingInDOMDocument:document];
    
    if (![[result tagName] isEqualToStringCaseInsensitive:[self tagName]]) result = nil;
    
    return result;
}

- (Class)DOMControllerClass;
{
    return [SVBodyParagraphDOMAdapter class];
}

- (void)readHTMLFromElement:(DOMHTMLElement *)element;
{
    //  Use the element to update our tagName, inner HTML, and inline graphics
    [self setTagName:[element tagName]];
    [self setArchiveString:[element innerHTML]];
}

#pragma mark Raw Properties

@dynamic tagName;
@dynamic archiveString;
@dynamic inlineGraphics;

#pragma mark  Links

@dynamic links;

- (NSArray *)orderedLinks;
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
    NSArray *result = [[self links] KS_sortedArrayUsingDescriptors:sortDescriptors];
    return result;
}

@end
