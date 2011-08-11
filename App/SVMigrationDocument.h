//
//  SVMigrationDocument.h
//  Sandvox
//
//  Created by Mike on 17/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "KTDocument.h"


@interface SVMigrationDocument : KTDocument
{
    IBOutlet NSTextField			*messageTextField;
	IBOutlet NSTextField			*informativeTextField;
	IBOutlet NSProgressIndicator	*progressIndicator;
	IBOutlet NSButton				*cancelButton;
        
  @private
    NSMigrationManager  *_migrationManager;
    
    id      _delegate;
    SEL     _saveSelector;
    void    *_contextInfo;
}

- (IBAction)cancelMigration:(id)sender;
- (IBAction)windowHelp:(id)sender;

@end
