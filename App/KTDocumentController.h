//
//  KTDocumentController.h
//  Marvel
//
//  Created by Terrence Talbot on 9/20/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class KTDocument;


@interface KTDocumentController : NSDocumentController
{
	KTDocument *myLastSavedDocumentWeakRef;
}

- (IBAction)showDocumentPlaceholderWindow:(id)sender;

@end
