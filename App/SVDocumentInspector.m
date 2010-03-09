//
//  SVDocumentInspector.m
//  Sandvox
//
//  Created by Dan Wood on 2/5/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDocumentInspector.h"

#import "KTDocument.h"
#import "KTMaster.h"

#import "KSCollectionController.h"


@implementation SVDocumentInspector

//  check representedObject property that's the document.  windowForSheet -- to forward the message....

- (IBAction)configureComments:(id)sender;
{
	KTDocument *doc = [self representedObject];
	NSLog(@"configureComments %@", doc);
	
}

- (IBAction)configureGoogle:(id)sender;
{
	NSBeep();
}

- (IBAction)chooseFavicon:(id)sender;
{
	KTDocument *document = [self representedObject];
    NSOpenPanel *panel = [document makeChooseDialog];
    
    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        NSURL *URL = [panel URL];
        
        KTMaster *master = [[[self inspectedObjectsController] selection] valueForKey:@"master"];
        [master setFaviconWithContentsOfURL:URL];
    }
}

- (IBAction)chooseBanner:(id)sender;
{
	KTDocument *document = [self representedObject];
    NSOpenPanel *panel = [document makeChooseDialog];
    
    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        NSURL *URL = [panel URL];
        
        KTMaster *master = [[[self inspectedObjectsController] selection] valueForKey:@"master"];
        [master setBannerWithContentsOfURL:URL];
    }
}

@end
