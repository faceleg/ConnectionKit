//
//  SVMediaGraphicInspector.m
//  Sandvox
//
//  Created by Mike on 10/08/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVMediaGraphicInspector.h"

#import "SVAudio.h"
#import "KTDocument.h"
#import "SVFlash.h"
#import "SVGraphicFactory.h"
#import "SVImage.h"
#import "SVVideo.h"

#import "KSWebLocation.h"

#import "NSBundle+Karelia.h"
#import "NSString+Karelia.h"


@implementation SVMediaGraphicInspector

#pragma mark Init

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    [self setTitle:NSLocalizedString(@"Media", "inspector title")];
    return self;
}

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

- (IBAction)chooseFile:(id)sender;
{
    KTDocument *document = [self representedObject];
    NSOpenPanel *panel = [document makeChooseDialog];
    
	// Use this 10.6 deprecated method, but when we are 10.6-only then use setAllowedFileTypes:
    if ([panel runModalForTypes:[SVMediaGraphic allowedTypes]] == NSFileHandlingPanelOKButton)
    {
        NSArray *URLs = [panel URLs];
        NSMutableArray *items = [[NSMutableArray alloc] initWithCapacity:[URLs count]];
        
        for (NSURL *aURL in URLs)
        {
            [items addObject:[KSWebLocation webLocationWithURL:aURL]];
        }
        
        for (SVMediaGraphic *aGraphic in [self inspectedObjects])
        {
            [aGraphic awakeFromPasteboardItems:items];
        }
        
        [items release];
    }
}

- (NSDragOperation)pathInfoField:(KSURLInfoField *)field
				validateFileDrop:(NSString *)path 
				   operationMask:(NSDragOperation)dragMask;
{
	// Check that the path looks like it is compatible with one of the allowed file types
	NSArray *allowedFileTypes = [SVMediaGraphic allowedTypes];
	BOOL OK = NO;
	if (allowedFileTypes && [allowedFileTypes count])
	{
		for (NSString *UTI in allowedFileTypes)
		{
			if ([[KSWORKSPACE ks_typeOfFileAtURL:[NSURL fileURLWithPath:path]] conformsToUTI:UTI])
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
	return OK ? (dragMask & NSDragOperationCopy) : NSDragOperationNone;
}

- (BOOL)pathInfoField:(KSURLInfoField *)field
 performDragOperation:(id <NSDraggingInfo>)sender
	 expectedDropType:(NSDragOperation)dragOp;
{
    BOOL result = NO;
    
	for (SVMediaGraphic *aGraphic in [self inspectedObjects])
    {
        // This code is very similar to SVImageDOMController. Perhaps can bring together
        NSPasteboard *pboard = [sender draggingPasteboard];
        
        NSString *type = [pboard availableTypeFromArray:[SVMediaPlugIn readableTypesForPasteboard:pboard]];
        if (type)
        {
            [aGraphic awakeFromPasteboardItems:[pboard sv_pasteboardItems]];
            result = YES;
        }
    }
    
    return result;
}

@end
