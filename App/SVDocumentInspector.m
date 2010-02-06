//
//  SVDocumentInspector.m
//  Sandvox
//
//  Created by Dan Wood on 2/5/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDocumentInspector.h"


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
	NSBeep();
}

- (IBAction)chooseBanner:(id)sender;
{
	NSBeep();
}

- (IBAction)chooseLogo:(id)sender;
{
	NSBeep();
}


@end
