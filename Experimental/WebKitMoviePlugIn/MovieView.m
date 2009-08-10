/*
 IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. ("Apple") in
 consideration of your agreement to the following terms, and your use, installation, 
 modification or redistribution of this Apple software constitutes acceptance of these 
 terms.  If you do not agree with these terms, please do not use, install, modify or 
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and subject to these 
 terms, Apple grants you a personal, non-exclusive license, under Apple’s copyrights in 
 this original Apple software (the "Apple Software"), to use, reproduce, modify and 
 redistribute the Apple Software, with or without modifications, in source and/or binary 
 forms; provided that if you redistribute the Apple Software in its entirety and without 
 modifications, you must retain this notice and the following text and disclaimers in all 
 such redistributions of the Apple Software.  Neither the name, trademarks, service marks 
 or logos of Apple Computer, Inc. may be used to endorse or promote products derived from 
 the Apple Software without specific prior written permission from Apple. Except as expressly
 stated in this notice, no other rights or licenses, express or implied, are granted by Apple
 herein, including but not limited to any patent rights that may be infringed by your 
 derivative works or by other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES, 
 EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, 
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS 
 USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL 
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS 
 OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, 
 REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND 
 WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR 
 OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "MovieView.h"

#import <WebKit/WebKit.h>

@implementation MovieView

+ (NSView *)plugInViewWithArguments:(NSDictionary *)arguments
{
    MovieView *movieView = [[[self alloc] init] autorelease];
    [movieView setArguments:arguments];
    return movieView;
}

- (void)dealloc
{   
    [_arguments release];
    [super dealloc];
}

- (void)setArguments:(NSDictionary *)arguments
{
    [arguments copy];
    [_arguments release];
    _arguments = arguments;
}

- (void)webPlugInInitialize
{
    [self showController:YES adjustingSize:NO];
}

- (void)webPlugInStart
{
		/* register for dragged types */
	[self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];

    if (!_loadedMovie) {
        _loadedMovie = YES;
        NSDictionary *webPluginAttributesObj = [_arguments objectForKey:WebPlugInAttributesKey];
        NSString *URLString = [webPluginAttributesObj objectForKey:@"src"];
        if (URLString != nil && [URLString length] != 0) {
            NSURL *baseURL = [_arguments objectForKey:WebPlugInBaseURLKey];
            NSURL *URL = [NSURL URLWithString:URLString relativeToURL:baseURL];
            NSMovie *movie = [[NSMovie alloc] initWithURL:URL byReference:NO];
            [self setMovie:movie];
            [movie release];
        }
		
			/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
		
			/* retrieve a reference to the container */
		id pluginContainer = [_arguments objectForKey:WebPlugInContainerKey];
		if (pluginContainer) {
		
				/* retrieve a reference to the webview */
			WebView *myWebView = [[pluginContainer webFrame] webView];
			
				/* make a simple call through to JavaScript. */
			[myWebView stringByEvaluatingJavaScriptFromString:@"RunMyPlugin();"];
		}
		
			/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

		
    }
    
    [self start:self];
}

- (void)webPlugInStop
{
	[self unregisterDraggedTypes];
    [self stop:self];
}

- (void)webPlugInDestroy
{
}

- (void)webPlugInSetIsSelected:(BOOL)isSelected
{
}

// Scripting support

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector
{
    if (selector == @selector(play) || selector == @selector(pause)) {
        return NO;
    }
    return YES;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)property
{
    if (strcmp(property, "muted") == 0) {
        return NO;
    }
    return YES;
}

- (id)objectForWebScript
{
    return self;
}

- (void)play
{
    [self start:nil];
}

- (void)pause
{
    [self stop:nil];
}




- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) == NSDragOperationGeneric)
    {
		[NSGraphicsContext saveGraphicsState];
		[self lockFocus];
	    NSSetFocusRingStyle(NSFocusRingOnly);
	    NSRectFill([self bounds]);
		[self unlockFocus];
		[NSGraphicsContext restoreGraphicsState];
		[self setNeedsDisplay:YES];

        return NSDragOperationGeneric;
    }
    else
    {
        //since they aren't offering the type of operation we want, we have 
            //to tell them we aren't interested
        return NSDragOperationNone;
    }
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	[[self superview] setNeedsDisplay:YES];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *paste = [sender draggingPasteboard];
        //gets the dragging-specific pasteboard from the sender
    NSArray *types = [NSArray arrayWithObjects:NSFilenamesPboardType, nil];
        //a list of types that we can accept
    NSString *desiredType = [paste availableTypeFromArray:types];
    NSData *carriedData = [paste dataForType:desiredType];

    if (nil == carriedData)
    {
        //the operation failed for some reason
        NSRunAlertPanel(@"Paste Error", @"Sorry, but the past operation failed", 
            nil, nil, nil);
        return NO;
    }
    else
    {
        //the pasteboard was able to give us some meaningful data
        if ([desiredType isEqualToString:NSFilenamesPboardType])
        {
            //we have a list of file names in an NSData object
            NSArray *fileArray = [paste propertyListForType:@"NSFilenamesPboardType"];
                //be caseful since this method returns id.  
                //We just happen to know that it will be an array.
            NSString *path = [fileArray objectAtIndex:0];
			CFShow(path);
		/*	if([delegate responsesToSelector:@"handleDrop:"])
				[delegate handleDrop:self];
				
				if(sender == myOutlet)
		*/
        }
        else
        {
            //this can't happen
            NSAssert(NO, @"This can't happen");
            return NO;
        }
    }
    
    return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	[[self superview] setNeedsDisplay:YES];
}

@end
