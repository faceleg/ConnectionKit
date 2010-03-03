//
//  SVDocumentInspector.h
//  Sandvox
//
//  Created by Dan Wood on 2/5/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSInspectorViewController.h"


@interface SVDocumentInspector : KSInspectorViewController {

}

- (IBAction)configureComments:(id)sender;
- (IBAction)configureGoogle:(id)sender;
- (IBAction)chooseFavicon:(id)sender;
- (IBAction)chooseBanner:(id)sender;

@end
