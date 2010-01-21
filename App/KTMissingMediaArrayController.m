//
//  KTMissingMediaArrayController.m
//  Marvel
//
//  Created by Mike on 10/11/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTMissingMediaArrayController.h"
#import "KTMissingMediaController.h"

#import "KTMediaManager+Internal.h"
#import "NSArray+Karelia.h"
#import "NSString+Karelia.h"

@implementation KTMissingMediaArrayController

#pragma mark -
#pragma mark Table Drag + Drop

+ (NSArray *)supportedDropTypes
{
	static NSArray *sDropTypes;
	
	if (!sDropTypes)
	{
		NSMutableArray *dropTypes = [NSMutableArray arrayWithObject:NSFilenamesPboardType];
		//[dropTypes addObjectsFromArray:[NSImage imagePasteboardTypes]];
		sDropTypes = [dropTypes copy];
	}
	
	return sDropTypes;
}

- (void)awakeFromNib
{
	[oTableView setDataSource:self];
    [oTableView setAllowsColumnSelection:NO];
	[oTableView registerForDraggedTypes:[[self class] supportedDropTypes]];
}

- (NSDragOperation)dragOperationForPath:(NSString *)path draggingMask:(NSDragOperation)draggingMask
{
	NSDragOperation result = NSDragOperationNone;
	
	
	// What what the media system prefer we do?
	NSDragOperation preferredOperation = NSDragOperationNone;
	if ([[windowController mediaManager] mediaFileShouldBeExternal:path]) {
		preferredOperation = NSDragOperationLink;
	}
	else {
		preferredOperation = NSDragOperationCopy;
	}
	
	
	// If the preferred action is available, take it
	if (draggingMask & preferredOperation)
	{
		result = preferredOperation;
	}
	// Otherwise do what the user asked for
	else
	{
		if (draggingMask & NSDragOperationLink)
		{
			result = NSDragOperationLink;
		}
		else if (draggingMask & NSDragOperationCopy)
		{
			result = NSDragOperationCopy;
		}
	}
	
	
	return result;
}

- (NSDragOperation)dragOperationForDrop:(id <NSDraggingInfo>)info toRepairMediaFile:(KTMediaFile *)mediaFile
{
	NSDragOperation result = NSDragOperationNone;
	
	// Make sure we're being offered a supported drop type
	NSString *dropType = [[info draggingPasteboard] availableTypeFromArray:[[self class] supportedDropTypes]];
	if (dropType)
	{
		// If being offered a file, make sure it's of a valid type and decide whether to copy or alias it
		if ([dropType isEqualToString:NSFilenamesPboardType])
		{
			NSArray *paths = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
			NSString *path = [paths firstObjectKS];
			
			if (path)
			{
				// Is the file type suitable?
				if ([NSString UTI:[NSString UTIForFileAtPath:path] conformsToUTI:[mediaFile fileType]])
				{
					result = [self dragOperationForPath:path draggingMask:[info draggingSourceOperationMask]];
				}
			}
		}
		else
		{
			result = NSDragOperationCopy;
		}
	}
	
	return result;
}

- (NSDragOperation)tableView:(NSTableView*)tableView
				validateDrop:(id <NSDraggingInfo>)info
				 proposedRow:(int)row
	   proposedDropOperation:(NSTableViewDropOperation)op
{
	//return [info draggingSourceOperationMask];
	
	NSDragOperation result = NSDragOperationNone;
	
	// Figure out where the drop should really be.
	NSPoint dropPoint = [tableView convertPoint:[info draggingLocation] fromView:nil];
	int dropRow = [tableView rowAtPoint:dropPoint];
	if (dropRow >= 0 && dropRow != NSNotFound)
	{
		[tableView setDropRow:dropRow dropOperation:NSTableViewDropOn];
		
		KTMediaFile *mediaFile = [[self arrangedObjects] objectAtIndex:dropRow];
		result = [self dragOperationForDrop:info toRepairMediaFile:mediaFile];
	}
	
	// This is needed to stop NSTableView highlighting a row when the drop becomes invalid
	if (result == NSDragOperationNone)
	{
		[tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
	}
	
	return result;
}

- (BOOL)tableView:(NSTableView *)aTableView
	   acceptDrop:(id < NSDraggingInfo >)info
			  row:(int)row
	dropOperation:(NSTableViewDropOperation)operation
{
	// Insert a new media file for the replacement media
	KTMediaFile *mediaFile = [[self arrangedObjects] objectAtIndex:row];
		NSDragOperation dragOperation = [self dragOperationForDrop:info  toRepairMediaFile:mediaFile];
	BOOL fileShouldBeExternal = NO;
	if (dragOperation & NSDragOperationLink)
	{
		fileShouldBeExternal = YES;
	}
	
	KTMediaFile *replacementMediaFile = [[windowController mediaManager] mediaFileWithDraggingInfo:info
																	preferExternalFile:fileShouldBeExternal];
	
	// Move the old media containers to the new media file
	KTMediaFile *oldMediaFile = [[self arrangedObjects] objectAtIndex:row];
	if (oldMediaFile)
	{
		[[replacementMediaFile mutableSetValueForKey:@"containers"] unionSet:[oldMediaFile valueForKey:@"containers"]];
		
		NSMutableArray *missingMedia = [windowController mutableArrayValueForKey:@"missingMedia"];
		unsigned index = [missingMedia indexOfObjectIdenticalTo:oldMediaFile];
		[missingMedia replaceObjectAtIndex:index withObject:replacementMediaFile];
		
		return YES;
	}
	
	return NO;
}

@end
