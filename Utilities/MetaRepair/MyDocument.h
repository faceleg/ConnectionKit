//
//  MyDocument.h
//  MetaRepair
//
//  Created by Terrence Talbot on 11/29/07.
//  Copyright Karelia Software 2007 . All rights reserved.
//


#import <Cocoa/Cocoa.h>

@interface MyDocument : NSDocument
{
	IBOutlet NSTextField *oFileNameField;
	IBOutlet NSTextField *oStatusField;
	
	NSString *_fileName;
}

- (IBAction)choose:(id)sender;
- (IBAction)repair:(id)sender;

- (NSString *)fileName;
- (void)setFileName:(NSString *)aFileName;

@end
