//
//  KTDocumentMigrationController.h
//  Marvel
//
//  Created by Mike on 27/03/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTDataMigrator;


@interface KTDataMigrationDocument : NSDocument
{
	IBOutlet NSTextField			*messageTextField;
	IBOutlet NSTextField			*informativeTextField;
	IBOutlet NSProgressIndicator	*progressIndicator;
	IBOutlet NSButton				*cancelButton;
    
    IBOutlet NSObjectController    *dataMigratorController;
    
@private
    
    KTDataMigrator  *myDataMigrator;
    NSMutableArray  *myCanCloseDocumentCallbacks;
}

- (IBAction)cancelMigration:(id)sender;

- (KTDataMigrator *)dataMigrator;

@end
