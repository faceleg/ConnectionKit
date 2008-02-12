//
//  NSImage+KTExtensions.h
//  KTComponents
//
//  Copyright (c) 2005-2006, Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import <AppKit/NSImage.h>

#import "CIImage+KTExtensions.h"

@class KTMedia;

@interface NSImage ( KTExtensions )

- (CIImage *)toCIImage;

+ (NSImage *)imageInBundle:(NSBundle *)bundle named:(NSString *)imageName;
+ (NSImage *)imageInBundle:(NSBundle *)bundle named:(NSString *)imageName inDirectory:(NSString *)directory;

+ (NSImage *)imageInBundleForClass:(Class)aClass named:(NSString *)imageName;
+ (NSImage *)imageInBundleForClass:(Class)aClass named:(NSString *)imageName inDirectory:(NSString *)directory;
+ (NSImage *)imageWithBitmap:(NSBitmapImageRep *)aBitmap;

- (id)initWithData:(NSData *)data ofMaximumSize:(int)aSize;
- (id)initWithContentsOfFile:(NSString *)fileName ofMaximumSize:(int)aSize;
- (id)initWithContentsOfURL:(NSURL *)url ofMaximumSize:(int)aSize;
- (id)initWithCGImageSourceRef:(CGImageSourceRef)aSource ofMaximumSize:(int)aSize;


- (NSImage *)normalizeSize;	// assumed for a bitmap image

// assumes kFitWithinRect, NSImageAlignCenter
- (NSImage *)imageWithMaxPixels:(int)aPixels;

// assumes kFitWithinRect, NSImageAlignCenter
- (NSImage *)imageWithMaxWidth:(int)aWidth height:(int)aHeight;

// assumes NSImageAlignCenter
- (NSImage *)imageWithMaxWidth:(int)aWidth height:(int)aHeight behavior:(CIScalingBehavior)aBehavior;

- (NSImage *)imageWithMaxWidth:(int)aWidth 
						height:(int)aHeight 
					  behavior:(CIScalingBehavior)aBehavior 
					 alignment:(NSImageAlignment)anAlignment;

- (NSBitmapImageRep *)bitmapByScalingWithBehavior:(KTImageScalingSettings *)settings;



- (NSBitmapImageRep *)bitmap;
- (NSBitmapImageRep *)firstBitmap;

- (NSData *)PNGRepresentation;
- (NSData *)PNGRepresentationWithOriginalMedia:(KTMedia *)parentMedia;
- (NSData *)JPEGRepresentationWithQuality:(float)aQuality;
- (NSData *)JPEGRepresentationWithQuality:(float)aQuality originalMedia:(KTMedia *)parentMedia;

- (NSData *)JPEG2000RepresentationWithQuality:(float)aQuality;

/*! returns UTI but also checks alpha */
- (NSString *)preferredFormatUTI;

+ (float)preferredJPEGQuality;

- (NSData *)preferredRepresentation;
- (NSData *)preferredRepresentationWithOriginalMedia:(KTMedia *)parentMedia;

- (NSData *)representationForMIMEType:(NSString *)aMimeType;
- (NSData *)representationForUTI:(NSString *)aUTI;

- (NSData *)faviconRepresentation;

- (NSImage *)trimmedVertically;
- (BOOL)hasAlphaComponent;

+ (NSImage *)brokenImage;
//+ (NSImage *)noImageImage;
//+ (NSImage *)noneImage;
+ (NSImage *)qmarkImage;
+ (NSImage *)movieImage;

- (float)width;
- (float)height;
- (void)embossPlaceholder;

+ (BOOL)containsImageDataAtPath:(NSString *)path;
//specific file tests

// Table button icons
+ (NSImage *)addToTableButtonIcon;
+ (NSImage *)removeFromTableButtonIcon;

@end
