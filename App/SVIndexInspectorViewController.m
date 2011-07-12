//
//  SVIndexInspectorViewController.m
//  Sandvox
//
//  Created by Terrence Talbot on 8/31/10.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "Sandvox.h"

#import "KTLinkSourceView.h"
#import "NSBundle+Karelia.h"
#import "KTDocument.h"


@implementation SVIndexInspectorViewController

- (void)loadView;
{
    // load CollectionInfo first
    [[NSBundle mainBundle] loadNibNamed:@"CollectionInfo" owner:self];
    NSView *collectionInfoView = [self view];
    
    // set up CollectionInfo
    [collectionLinkSourceView setCollectionsOnly:YES];     
    
	// Connect up the target icon if needed
	NSArray *selectedObjects = [[self inspectedObjectsController] selectedObjects];
	id<SVPage> collection = (id<SVPage>)[NSNull null];		// placeholder for not known
	NSCellStateValue state = NSMixedState;
	for ( SVIndexPlugIn *plugIn in selectedObjects )
	{
		if ( (collection == (id<SVPage>)[NSNull null]) )
		{
			collection = plugIn.indexedCollection;	// first pass through
			state = (nil != collection) ? NSOnState : NSOffState;
		}
		else
		{
			if ( collection != plugIn.indexedCollection )
			{
				state = NSMixedState;
				break;		// no point in continuing; it's a mixed state and there's no going back
			}
		}
	}
	[collectionLinkSourceView setConnected:(state == NSOnState)];    
    
    // Load proper view
    if ( nil != [self nibName] )
    {
        [super loadView];
        
        // Cobble the two together
        NSView *otherView = [self view];
        
        NSView *view = [[NSView alloc] initWithFrame:
                        NSMakeRect(0.0f,
                                   0.0f,
                                   230.0f,
                                   [collectionInfoView frame].size.height + [otherView frame].size.height)];
        
        [view setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        
        NSRect collectionInfoFrame = [collectionInfoView frame];
        NSRect otherViewFrame;
        NSDivideRect([view bounds],
                     &collectionInfoFrame,
                     &otherViewFrame,
                     collectionInfoFrame.size.height,
                     NSMaxYEdge);
        
        [collectionInfoView setFrame:collectionInfoFrame];
        [view addSubview:collectionInfoView];
        
        [otherView setFrame:otherViewFrame];
        [view addSubview:otherView];
        
        [self setContentHeightForViewInInspector:0];    // reset so -setView: handles it
        [self setView:view];
        [view release];        
    }
}

- (void)setRepresentedObject:(id)representedObject
{
    [super setRepresentedObject:representedObject];
    [collectionLinkSourceView setTargetWindow:[(KTDocument *)representedObject windowForSheet]]; // hack for testing purposes
}

- (void)linkSourceConnectedTo:(id<SVPage>)aPage
{
	if (aPage)
	{
        [collectionLinkSourceView setConnected:YES];
        
        // Store the new collection. For some reason keypath of @"indexedCollection" is upsetting KVO heavily. #102661
        [[[self inspectedObjectsController] selection] setValue:[aPage self]    // to be sure it's not a proxy
                                                     forKeyPath:@"container.indexedCollection"];
        
        // When we change indexedCollection, set the container's title to the title of the collection, or to
        // CFBundleDisplayName if collection is nil
		if ( [aPage title] )
        {
            [[[self inspectedObjectsController] selection] setValue:[aPage title] forKey:@"title"];
        }
        else
        {
            NSString *defaultTitle = [[self nibBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
            [[[self inspectedObjectsController] selection] setValue:defaultTitle forKey:@"title"];
        }
	}
    else
    {
        [collectionLinkSourceView setConnected:NO]; // is this branch ever taken?
    }
}

@end
