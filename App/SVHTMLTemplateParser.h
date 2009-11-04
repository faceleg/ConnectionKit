//
//  SVHTMLTemplateParser.h
//  Sandvox
//
//  Copyright 2005-2009 Karelia Software. All rights reserved.
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


#import "KTTemplateParser.h"

#import "SVHTMLGenerationContext.h"


@class KTDocument, KTHTMLParserMasterCache, SVHTMLGenerationContext, KTMediaFileUpload, SVHTMLTemplateTextBlock;
@class KTAbstractPage;
@class KTMediaContainer, KTMediaFile;
@protocol SVHTMLTemplateParserDelegate;


@interface SVHTMLTemplateParser : KTTemplateParser

- (id)initWithPage:(KTAbstractPage *)page;	// Convenience method that parses the whole page

@property(nonatomic, assign) id <SVHTMLTemplateParserDelegate> delegate;


#pragma mark Parse
//  Convenience method to do parsing while pushing and popping a context on the stack
- (NSString *)parseTemplateWithContext:(SVHTMLGenerationContext *)context;


// Functions
- (NSString *)pathToObject:(id)anObject;


// Prebuilt templates
+ (NSString *)calloutContainerTemplateHTML;
- (NSString *)calloutContainerTemplateHTML;

- (NSString *)targetStringForPage:(id) aDestPage;

@end


@interface SVHTMLTemplateParser (Media)

- (NSString *)info:(NSString *)infoString forMedia:(KTMediaContainer *)media scalingProperties:(NSDictionary *)scalingSettings;

- (NSString *)pathToMedia:(KTMediaFile *)media scalingProperties:(NSDictionary *)scalingProps;
- (NSString *)widthStringForMediaFile:(KTMediaFile *)mediaFile scalingProperties:(NSDictionary *)scalingProps;
- (NSString *)heightStringForMediaFile:(KTMediaFile *)mediaFile scalingProperties:(NSDictionary *)scalingProps;

@end


@interface SVHTMLTemplateParser (Text)
- (SVHTMLTemplateTextBlock *)textblockForKeyPath:(NSString *)keypath ofObject:(id)object
									  flags:(NSArray *)flags
								    HTMLTag:(NSString *)tag
						  graphicalTextCode:(NSString *)GTCode
								  hyperlink:(KTAbstractPage *)hyperlink;
@end


@protocol SVHTMLTemplateParserDelegate <KTTemplateParserDelegate>
@optional
- (void)HTMLParser:(SVHTMLTemplateParser *)parser didEncounterResourceFile:(NSURL *)resourcePath;
- (void)HTMLParser:(SVHTMLTemplateParser *)parser didParseMediaFile:(KTMediaFile *)mediaFile upload:(KTMediaFileUpload *)upload;
@end

