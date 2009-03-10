//
//  KT.h
//  Sandvox
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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

// KT.h lists #defines, enums, and NSStrings that are used throughout Sandvox
// they can only be #imported once, so they are kept separately from SandvoxPlugin.h

// LocalizedStringInThisBundle should be used by PLUGINS, but WARNING not in category methods
// as the class will have the wrong bundle. Code in Sandvox.app should always just use standard NSLocalized* macros.
#define LocalizedStringInThisBundle(key, comment) [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:nil]

// Description Forthcoming (corresponds to pop-up tags in Info.nib)
typedef enum {
	KTCommentsProviderNone = 0,
	KTCommentsProviderHaloscan,
	KTCommentsProviderJSKit,
	KTCommentsProviderDisqus,
	KTCommentsProviderIntenseDebate
} KTCommentsProvider;

// Description Forthcoming
typedef enum {
    KTCollectionSortUnspecified = -1,		// used internally
	KTCollectionUnsorted = 0, 
    KTCollectionSortAlpha,
    KTCollectionSortLatestAtBottom,
	KTCollectionSortLatestAtTop,		// = 3 ... default
	KTCollectionSortReverseAlpha,
} KTCollectionSortType;

// Description Forthcoming
typedef enum {
	KTSummarizeAutomatic = 1,
	KTSummarizeMostRecent,
	KTSummarizeRecentList,
	KTSummarizeAlphabeticalList,
	KTSummarizeFirstItem	// this was added later, that's why it's at the end
} KTCollectionSummaryType;

// Description Forthcoming
typedef enum {
	KTTimestampCreationDate = 1,
	KTTimestampModificationDate
} KTTimestampType;

// Description Forthcoming
typedef enum {
	KTHTML401DocType = 0,
	KTXHTMLTransitionalDocType,
	KTXHTMLStrictDocType,
	KTXHTML11DocType
} KTDocType;

// Document
extern NSString *kKTDocumentType;
extern NSString *kKTDocumentExtension;
extern NSString *kKTDocumentUTI; // 1.5+ documents
extern NSString *kKTDocumentUTI_ORIGINAL; // 1.0-1.2 documents

extern NSString *kKTPageIDDesignator;

// Spotlight metadata keys
extern NSString *kKTMetadataAppCreatedVersionKey; // CFBundleVersion which created document
extern NSString *kKTMetadataAppLastSavedVersionKey;  // CFBundleVersion which last saved document
extern NSString *kKTMetadataModelVersionKey;

// Core Data
extern NSString *kKTModelVersion;
extern NSString *kKTModelVersion_ORIGINAL;
extern NSString *kKTModelMinimumVersion;  // we'll support models >= this
extern NSString *kKTModelMaximumVersion;  // we'll support models <= this

// DataSources
extern NSString *kKTDataSourceFileName;	// name of file, with extension -- may not be on file system!
extern NSString *kKTDataSourceFilePath;	// path of actual file
extern NSString *kKTDataSourceTitle;	// title other than the file name, if it's known
extern NSString *kKTDataSourceNil;      // indicate an empty datasource, return nil
extern NSString *kKTDataSourceRecurse;
extern NSString *kKTDataSourceCaption;
extern NSString *kKTDataSourceURLString;
extern NSString *kKTDataSourceImageURLString;
extern NSString *kKTDataSourcePreferExternalImageFlag;
extern NSString *kKTDataSourceShouldIncludeLinkFlag;
extern NSString *kKTDataSourceLinkToOriginalFlag;
extern NSString *kKTDataSourceFeedURLString;
extern NSString *kKTDataSourcePlugin;
extern NSString *kKTDataSourceImage;
extern NSString *kKTDataSourceData;
extern NSString *kKTDataSourceUTI;
extern NSString *kKTDataSourceString;
extern NSString *kKTDataSourceCreationDate;
extern NSString *kKTDataSourceKeywords;
extern NSString *kKTDataSourcePasteboard;

// Error Domains
extern NSString *kKTHostSetupErrorDomain;
extern NSString *kKTConnectionErrorDomain;
extern NSString *kKTDataMigrationErrorDomain;

// Exceptions
extern NSString *kKTTemplateParserException;

// Pasteboards
extern NSString *kKTOutlineDraggingPboardType;
extern NSString *kKTPagesPboardType;
extern NSString *kKTPageletsPboardType;

// Plugin Extensions
extern NSString *kKTIndexExtension;
extern NSString *kKTElementExtension;
extern NSString *kKTDesignExtension;

// Notifications
extern NSString *kKTDesignChangedNotification;
extern NSString *kKTInfoWindowMayNeedRefreshingNotification; // not currently used
extern NSString *kKTItemSelectedNotification;

// Site Outline
extern NSString *kKTSelectedObjectsKey;
extern NSString *kKTSelectedObjectsClassNameKey;

// Site Publication
extern NSString *kKTDefaultMediaPath;
extern NSString *kKTDefaultResourcesPath;

extern NSString *kKTInternalImageClassName;
