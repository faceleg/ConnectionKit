//
//  SVLinkInspector.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVLinkInspector.h"
#import "SVLinkManager.h"

#import "KTDocument.h"
#import "KTDocWindowController.h"
#import "KTPage.h"
#import "KSURLFormatter.h"

#import "DOMRange+Karelia.h"


@implementation SVLinkInspector

#pragma mark View

- (void)loadView
{
    [super loadView];
    [self refresh];
}

#pragma mark Inspection

@synthesize inspectedWindow = _inspectedWindow;

- (DOMHTMLAnchorElement *)inspectedLink
{
    DOMHTMLAnchorElement *result = nil;
    
    NSArray *selection = [self inspectedObjects];
    if ([selection count] == 1) result = [selection objectAtIndex:0];
    
    return result;
}

- (void)refresh
{
    [super refresh];
    
    
    // Make the link field editable if there is nothing entered, or the URL is typed in
    BOOL editable = YES;
    NSArray *selection = [self inspectedObjects];
    if ([selection count] == 1)
    {
        id link = [selection objectAtIndex:0];
        if ([link respondsToSelector:@selector(isLocalLink)])
        {
            editable = ![link boolForKey:@"localLink"];
        }
    }
    
    [oLinkField setEditable:editable];
    [oLinkField setBackgroundColor:(editable ? [NSColor textBackgroundColor] : [NSColor controlHighlightColor])];
    if (editable)
    {
        if (!_URLFormatter) _URLFormatter = [[KSURLFormatter alloc] init];
        [oLinkField setFormatter:_URLFormatter];
    }
    else
    {
        [oLinkField setFormatter:nil];
    }
}

- (SVLinkManager *)sharedLinkManager
{
    // Exposed only here for the benefit of bindings
    return [SVLinkManager sharedLinkManager];
}

#pragma mark Link Actions

- (id)userInfoForLinkSource:(KTLinkSourceView *)link
{
	return [[[[self inspectedWindow] windowController] document] site];
}

- (NSPasteboard *)linkSourceDidBeginDrag:(KTLinkSourceView *)link
{
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[pboard declareTypes:[NSArray arrayWithObject:kKTLocalLinkPboardType] owner:self];
	[pboard setString:@"LocalLink" forType:kKTLocalLinkPboardType];
	
	return pboard;
}

- (void)linkSourceDidEndDrag:(KTLinkSourceView *)link withPasteboard:(NSPasteboard *)pboard
{
	// set up a link to the local page
    NSString *pageID = [pboard stringForType:kKTLocalLinkPboardType];
    if ( (pageID != nil) && ![pageID isEqualToString:@""] )
    {
        KTPage *target = [KTPage pageWithUniqueID:pageID inManagedObjectContext:[[[[self inspectedWindow] windowController] document] managedObjectContext]];
        if ( nil != target )
        {
            NSString *titleText = [[target title] text];
            if ( (nil != titleText) && ![titleText isEqualToString:@""] )
            {
                //[oLinkLocalPageField setStringValue:titleText];
                //[oLinkDestinationField setStringValue:@""];
                //[oLinkLocalPageField setHidden:NO];
                //[oLinkDestinationField setHidden:YES];
                
                NSString *href = [NSString stringWithFormat:@"%@%@", kKTPageIDDesignator, pageID];
                if ([self inspectedLink])
                {
                    [[self inspectedLink] setHref:href];
                }
                else
                {
                }
                
                
                [link setConnected:YES];
                
            }
        }
    }
}

- (IBAction)setLinkURL:(id)sender;
{
    NSString *URLString = [oLinkField stringValue];
    OBASSERT(!_linkDestination);
    _linkDestination = URLString;
    OBASSERT([[self linkDestinationURLString] isEqualToString:URLString]);
    
    [[[self inspectedWindow] firstResponder] tryToPerform:@selector(changeLinkDestination:) with:self];
    
    _linkDestination =  nil;
}

- (IBAction)clearLinkDestination:(id)sender;
{
	//[oLinkLocalPageField setStringValue:@""];
	//[oLinkDestinationField setStringValue:@""];
	//[oLinkLocalPageField setHidden:YES];
	//[oLinkDestinationField setHidden:NO];
	//[oLinkView setConnected:NO];
    
    OBASSERT(![self linkDestinationURLString]);
    [[[self inspectedWindow] firstResponder] tryToPerform:@selector(changeLinkDestination:) with:self];
}

- (NSString *)linkDestinationURLString; { return _linkDestination; }

@end
