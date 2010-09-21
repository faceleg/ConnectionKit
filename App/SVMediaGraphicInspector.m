//
//  SVMediaGraphicInspector.m
//  Sandvox
//
//  Created by Mike on 10/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaGraphicInspector.h"

#import "SVAudio.h"
#import "KTDocument.h"
#import "SVFlash.h"
#import "SVImage.h"
#import "SVVideo.h"

#import "NSBundle+Karelia.h"
#import "NSString+Karelia.h"


@implementation SVMediaGraphicInspector

#pragma mark View

- (void)loadView;
{
    // Load File Info first
    [[NSBundle mainBundle] loadNibNamed:@"FileInfo" owner:self];
    NSView *fileInfoView = [self view];
    
    // Load proper view
    [super loadView];
    
    // Cobble the two together
    NSView *otherView = [self view];
    
    NSView *view = [[NSView alloc] initWithFrame:
                    NSMakeRect(0.0f,
                               0.0f,
                               230.0f,
                               [fileInfoView frame].size.height + [otherView frame].size.height)];
    
    [view setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    
    NSRect fileInfoFrame = [fileInfoView frame];
    NSRect otherViewFrame;
    NSDivideRect([view bounds],
                 &fileInfoFrame,
                 &otherViewFrame,
                 fileInfoFrame.size.height,
                 NSMaxYEdge);
    
    [fileInfoView setFrame:fileInfoFrame];
    [view addSubview:fileInfoView];
    
    [otherView setFrame:otherViewFrame];
    [view addSubview:otherView];
    
    [self setContentHeightForViewInInspector:0];    // reset so -setView: handles it
    [self setView:view];
    [view release];
}

- (IBAction)enterExternalURL:(id)sender;
{
    NSWindow *window = [oURLField window];
    [window makeKeyWindow];
    [oURLField setHidden:NO];
    [window makeFirstResponder:oURLField];
}

- (NSArray *)allowedFileTypes;		// try to figure out allowed file types for all selections
{
	NSMutableSet *result = [NSMutableSet set];
    [result addObjectsFromArray:[SVImage allowedFileTypes]];
    [result addObjectsFromArray:[SVVideo allowedFileTypes]];
    [result addObjectsFromArray:[SVAudio allowedFileTypes]];
    [result addObjectsFromArray:[SVFlash allowedFileTypes]];
    
	return [result allObjects];
}

- (IBAction)chooseFile:(id)sender;
{
    KTDocument *document = [self representedObject];
    NSOpenPanel *panel = [document makeChooseDialog];
    
	// Use this 10.6 deprecated method, but when we are 10.6 only then use setAllowedFileTypes:
    if ([panel runModalForTypes:[self allowedFileTypes]] == NSFileHandlingPanelOKButton)
    {
        NSURL *URL = [panel URL];
        NSString *type = [NSString UTIForFileAtPath:[URL path]];
        
        for (SVMediaGraphic *aGraphic in [self inspectedObjects])
        {
            // Does this require a change of media type?
            if (![[aGraphic class] acceptsType:type])
            {
                if ([SVVideo acceptsType:type])
                {
                    NSManagedObjectContext *context = [aGraphic managedObjectContext];
                    SVVideo *video = [SVVideo insertNewGraphicInManagedObjectContext:context];
                    [video setTextAttachment:[aGraphic textAttachment]];
                    [video setValue:[aGraphic sidebars] forKey:@"sidebars"];
                    
                    [context deleteObject:aGraphic];
                    aGraphic = video;
                }
            }
            
            [aGraphic setMediaWithURL:URL];
        }
    }
}

- (NSDragOperation)pathInfoField:(KSURLInfoField *)field
				validateFileDrop:(NSString *)path 
				   operationMask:(NSDragOperation)dragMask;
{
	// Check that the path looks like it is compatible with one of the allowed file types
	NSArray *allowedFileTypes = [self allowedFileTypes];
	BOOL OK = NO;
	if (allowedFileTypes && [allowedFileTypes count])
	{
		for (NSString *UTI in allowedFileTypes)
		{
			if ([[NSString UTIForFileAtPath:path] conformsToUTI:UTI])
			{
				OK = YES;
				break;
			}
		}
	}
	else
	{
		OK = YES;		// be permissive; no allowed file types defined
	}
	return OK ? dragMask & NSDragOperationCopy : NSDragOperationNone;
}

- (BOOL)pathInfoField:(KSURLInfoField *)field
 performDragOperation:(id <NSDraggingInfo>)sender
	 expectedDropType:(NSDragOperation)dragOp;
{
	BOOL result = NO;
	NSPasteboard *pasteboard = [sender draggingPasteboard];

	// Only allow through suitable file drags
	if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
	{
		NSArray *files = [pasteboard propertyListForType:NSFilenamesPboardType];
		if (files && [files count] == 1)
		{
			NSString *path = [files objectAtIndex:0];
			NSURL *URL = [NSURL fileURLWithPath:path];

			[[self inspectedObjects] makeObjectsPerformSelector:@selector(setMediaWithURL:)
													 withObject:URL];
			result = YES;
		
		}
	}
	return result;
}

@end
