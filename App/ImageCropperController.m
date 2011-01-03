//
//  ImageCropperController.m
//  KTComponents
//
//  Created by Dan Wood on 9/20/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "ImageCropperController.h"
#import "CroppingImageView.h"

static ImageCropperController *sImageCropperController = nil;


@implementation ImageCropperController

+ (ImageCropperController *)sharedImageCropperControllerCreate:(BOOL)aCreate
{
	if ((nil == sImageCropperController) && aCreate)
	{
		sImageCropperController = [[ImageCropperController alloc] init];
	}
	[sImageCropperController reset];		// clear out for each new use
	return sImageCropperController;
}

- (id)init
{
    self = [super initWithWindowNibName:@"ImageCropper"];
    return self;
}

- (void)reset
{
	[self setOriginalImage:nil];
	[self setOriginalImagePath:nil];
}

- (void)dealloc
{
	[self reset];
	[super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
	[oController setContent:self];
	
}

- (void)windowWillClose:(NSNotification *)notification;
{
	[oController setContent:nil];
}

#pragma mark -
#pragma mark Actions

- (IBAction) zoomOut:(id)sender
{
	[oCroppingImageView setZoom:0.0];
}
- (IBAction) zoomIn:(id)sender
{
	[oCroppingImageView setZoom:1.0];
}

/*!	informs delegate of choice (which could be nil if no image chosen), and nil cropped image if not cropped
*/
- (IBAction) doOK:(id)sender
{
	if ([myDelegate respondsToSelector:@selector(imagePickerSet:)])
	{
		[myDelegate imagePickerSet:self];
	}
	[self close];
}

- (IBAction) doCancel:(id)sender
{
	if ([myDelegate respondsToSelector:@selector(imagePickerCancelled:)])
	{
		[myDelegate imagePickerCancelled:self];
	}
	[self close];
}

- (IBAction) chooseFile:(id)sender
{
	[[NSOpenPanel openPanel] setAllowsMultipleSelection:NO];
	[[NSOpenPanel openPanel] setTreatsFilePackagesAsDirectories:YES];
	[[NSOpenPanel openPanel]
		beginSheetForDirectory:nil
						  file:nil
						 types:[NSImage imageFileTypes]
				modalForWindow:[self window]
				 modalDelegate:self
				didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
				   contextInfo:nil];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (NSOKButton == returnCode)
	{
		NSArray *filenames = [sheet filenames];
		if ([filenames count])
		{
			[self reset];
			NSString *path = [filenames objectAtIndex:0];
			NSImage *im = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
			[self setOriginalImagePath:path];
			[self setOriginalImage:im];
		}
	}
}

#pragma mark -
#pragma mark Accessors

- (CroppingImageView *)croppingImageView;
{
	return oCroppingImageView;
}

- (NSImage *)originalImage
{
    return myOriginalImage; 
}

- (void)setOriginalImage:(NSImage *)anOriginalImage
{
    [anOriginalImage retain];
    [myOriginalImage release];
    myOriginalImage = anOriginalImage;
	
	[oCroppingImageView setImage:anOriginalImage];
	[oCroppingImageView setZoom:0.0];
}

- (NSString *)originalImagePath
{
    return myOriginalImagePath; 
}

- (void)setOriginalImagePath:(NSString  *)anOriginalImagePath
{
    [anOriginalImagePath retain];
    [myOriginalImagePath release];
    myOriginalImagePath = anOriginalImagePath;
}

/*!	Get cropped image from controller.  If not cropped, returns nil
*/
- (NSImage *)croppedImage
{
    return [oCroppingImageView croppedImage]; 
}




- (id)delegate
{
    return myDelegate; 
}

- (void)setDelegate:(id)aDelegate
{
    myDelegate = aDelegate;
}


@end
