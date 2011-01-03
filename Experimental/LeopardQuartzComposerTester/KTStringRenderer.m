//
//  KTStringRenderer.m
//  Marvel
//
//  Created by Dan Wood on 3/10/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "KTStringRenderer.h"
#import <OpenGL/CGLMacro.h>

static NSMutableDictionary *sRendererDictionary = nil;

@implementation KTStringRenderer

/*!	Create a dictionary so we can keep our renderers around so we don't have to keep creating them.
*/
+ (void)initialize	// +initialize is preferred over +load when possible
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	sRendererDictionary = [[NSMutableDictionary alloc] init];
	[pool release];
}

- (id)initWithQCRenderer:(QCRenderer *)aRenderer fileName:(NSString *)fileName;
{
	if (self = [super init])
	{
		myRenderer = [aRenderer retain];
		myFileName = [fileName retain];
	}
	return self;
}


- (void)dealloc
{
    [myRenderer release];
	[myFileName release];
    [super dealloc];
}


+ (KTStringRenderer *)rendererWithFile:(NSString *)aFileName
{
	int width = 501;
	int height = 502;
	
	KTStringRenderer *result = [sRendererDictionary objectForKey:aFileName];
	if (nil == result)
	{
		NSOpenGLPixelFormatAttribute	attributes[] = {
			NSOpenGLPFAAccelerated,
			NSOpenGLPFANoRecovery,
			(NSOpenGLPixelFormatAttribute)0
		};
		NSOpenGLPixelFormat*	format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
		NSOpenGLContext*		context = [[NSOpenGLContext alloc] initWithFormat:format shareContext:nil];
		CGLContextObj			cgl_ctx = [context CGLContextObj];
		if(cgl_ctx)
		{
			glViewport(0, 0, width, height);
		}
		QCRenderer*				renderer = [[QCRenderer alloc] initWithOpenGLContext:context pixelFormat:format file:aFileName];
		
		result = [[[KTStringRenderer alloc] initWithQCRenderer:renderer fileName:aFileName] autorelease];
		[sRendererDictionary setObject:result forKey:aFileName];	// save for later lookup
		
		[renderer release];
		[context release];
		[format release];
	}
	return result;
}

- (NSImage *)imageWithInputs:(NSDictionary *)inputs
{
	NSImage *result = nil;
	
	// Set inputs ... should this happen before or after render?
	NSEnumerator *theEnum = [inputs keyEnumerator];
	id key;
	while (nil != (key = [theEnum nextObject]) )
	{
		id value = [inputs objectForKey:key];
		BOOL success = NO;
		@try
		{
			success = [myRenderer setValue:value forInputKey:key];
		}
		@catch (NSException *e)
		{
		}
		if (!success)
		{
			NSLog(@"Unable to setValue:%@ forInputKey:%@ for composition:%@, please update this Quartz Composer file to current Sandvox Spec.", value, key, [myFileName stringByAbbreviatingWithTildeInPath]);
		}
	}
	
    BOOL renderSuccess = [myRenderer renderAtTime:0.0 arguments:nil];
	if (!renderSuccess)
	{
		NSLog(@"QC Renderer %@ failed to render", myRenderer);
	}

	id image = [myRenderer valueForOutputKey:@"Image" ofType:@"CGImage"];
	NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithCGImage:image] autorelease];
	NSData *data = [bitmap TIFFRepresentation];
	result = [[[NSImage alloc] initWithData:data] autorelease];
	return result;
}

@end
