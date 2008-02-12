
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
        NSRunAlertPanel(@"Paste Error", @"Sorry, but the paste operation failed", 
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
