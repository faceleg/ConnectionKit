//
//  MyDocument.m
//  MetaRepair
//
//  Created by Terrence Talbot on 11/29/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "MyDocument.h"

@implementation MyDocument

- (id)init
{
    self = [super init];
    if (self) {
    
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
    
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If the given outError != NULL, ensure that you set *outError when returning nil.

    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.

    // For applications targeted for Panther or earlier systems, you should use the deprecated API -dataRepresentationOfType:. In this case you can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.

    if ( outError != NULL ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
	return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to read your document from the given data of the specified type.  If the given outError != NULL, ensure that you set *outError when returning NO.

    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead. 
    
    // For applications targeted for Panther or earlier systems, you should use the deprecated API -loadDataRepresentation:ofType. In this case you can also choose to override -readFromFile:ofType: or -loadFileWrapperRepresentation:ofType: instead.
    
    if ( outError != NULL ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
    return YES;
}

- (IBAction)choose:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setCanChooseDirectories:NO];
	
	[openPanel beginSheetForDirectory:nil
								 file:nil
								types:[NSArray arrayWithObject:@"svxSite"]
					   modalForWindow:[[[self windowControllers] objectAtIndex:0] window]
						modalDelegate:self
					   didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:nil];
	 
}
	 
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if ( NSOKButton == returnCode )
	{
		[self setFileName:[panel filename]];
		[oFileNameField setStringValue:[self fileName]];
		[oStatusField setStringValue:@"Awaiting Repair"];
	}
	
	[panel orderOut:self];
}

- (IBAction)repair:(id)sender
{
	// get good metadata from Sample site
	NSString *samplePath = [[NSBundle mainBundle] pathForResource:@"Sample" ofType:@"svxSite"];
	NSURL *sampleURL = [NSURL fileURLWithPath:samplePath];
	
	NSError *localError = nil;
	NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreWithURL:sampleURL
																					   error:&localError];
	
	// write good metadata on selected site
	NSURL *repairURL = [NSURL fileURLWithPath:[self fileName]];
	BOOL result = [NSPersistentStoreCoordinator setMetadata:metadata
								   forPersistentStoreOfType:NSSQLiteStoreType
														URL:repairURL
													  error:&localError];
	if ( !result )
	{
		NSBeep(); NSBeep();
		if ( nil != localError )
		{
			[oStatusField setStringValue:[localError localizedDescription]];
		}
		else
		{
			[oStatusField setStringValue:@"Did Not Repair"];
		}
	}
	else
	{
		[oStatusField setStringValue:@"Repaired"];
	}
}

- (NSString *)fileName
{
	return _fileName;
}

- (void)setFileName:(NSString *)aFileName
{
	[aFileName retain];
	[_fileName release];
	_fileName = aFileName;
}


@end
