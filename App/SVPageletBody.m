// 
//  SVPageletContent.m
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPageletBody.h"

#import "KTPagelet.h"
#import "SVContentObject.h"

#import "DOMNode+Karelia.h"

#import <WebKit/WebKit.h>


@interface SVPageletBody ()
@property(nonatomic, copy, readwrite) NSSet *contentObjects;
@end


#pragma mark -


@implementation SVPageletBody 

#pragma mark Owner

@dynamic pagelet;

#pragma mark Content

@dynamic archiveHTMLString;
@dynamic contentObjects;

- (void)setArchiveHTMLString:(NSString *)html
              contentObjects:(NSSet *)contentObjects;
{
    [self setArchiveHTMLString:html];
    [self setContentObjects:contentObjects];
}

// TODO: Write validation methods

#pragma mark HTML

- (NSString *)HTMLString;
{
    // Take archived HTML and insert editing HTML for content objects into it. We do this now so as to generate as close as possible an approximation to how the page will look when published. (The alternative is to load archived HTML into the DOM, and then replace individual nodes with content objects)
    NSString *result = [self archiveHTMLString];
    
    if ([[self contentObjects] count] > 0)
    {
        NSMutableString *buffer = [result mutableCopy];
        
        // Insert each content object
        for (SVContentObject *aContentObject in [self contentObjects])
        {
            NSString *target = [aContentObject archiveHTMLString];
            [buffer replaceOccurrencesOfString:target
                                    withString:[aContentObject HTMLString]
                                       options:0 
                                         range:NSMakeRange(0, [buffer length])];
        }
        
        
        // Tidy up
        result = buffer;
        [buffer autorelease];
    }
    
    return result;
}

- (DOMElement *)elementForContentObject:(SVContentObject *)contentObject
                           inDOMElement:(DOMElement *)textAreaDOMElement;
{
    OBPRECONDITION([[self contentObjects] containsObject:contentObject]);
    
    DOMElement *result = [contentObject DOMElementInDocument:[textAreaDOMElement ownerDocument]];
    
    if (![result isDescendantOfNode:textAreaDOMElement]) result = nil;
    return result;
}

@end
