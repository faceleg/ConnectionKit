//
//  SVVideoInspector.m
//  Sandvox
//
//  Created by Dan Wood on 8/6/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVVideoInspector.h"

#import "KTDocument.h"
#import "NSImageView+IMBImageItem.h"
#import "SVVideo.h"
#import "SVMediaPlugIn.h"

@implementation SVVideoInspector

- (void)loadView;
{
    [super loadView];
    
    [oPosterImageView bind:IMBImageItemBinding toObject:self withKeyPath:@"inspectedObjectsController.selection.posterFrame" options:nil];
}

- (IBAction)choosePosterFrame:(id)sender;
{
	KTDocument *document = [self representedObject];
    NSOpenPanel *panel = [document makeChooseDialog];
	[panel setAllowedFileTypes:[NSArray arrayWithObject:(NSString *)kUTTypeImage]];

    if ([panel runModalForTypes:[panel allowedFileTypes]] == NSFileHandlingPanelOKButton)
    {
        NSURL *URL = [panel URL];
        
		for (id inspectedObject in [self inspectedObjects])
		{
			if ([inspectedObject respondsToSelector:@selector(setPosterFrameWithContentsOfURL:)])
			{
				[inspectedObject setPosterFrameWithContentsOfURL:URL];
			}
		}
        ;
    }
}

@end
