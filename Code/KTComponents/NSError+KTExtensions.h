//
//  NSError+KTExtensions.h
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

#import <Cocoa/Cocoa.h>

enum {
	KTGenericError = 65531,	// arbitrary error code, app should get what it needs from userInfo
	
	KTCannotUpgrade = 4321,
	KTNoDocPathSpecified,
	KTPathIsDirectory,
	KTCannotRemove,
	KTDirNotWritable,
	KTParentNotDirectory
	
};

extern NSString *kKTGenericErrorDomain;
extern NSString *kKTURLPrococolErrorDomain;
extern NSString *kKTHostSetupDomain;
extern NSString *kKTConnectionDomain;
extern NSString *kKTDataMigrationErrorDomain;


@interface NSError ( KTExtensions )

// convenience constructors

/*! returns error with aLocalizedDescription in anErrorDomain with anErrorCode */
+ (id)errorWithDomain:(NSString *)anErrorDomain code:(int)anErrorCode localizedDescription:(NSString *)aLocalizedDescription;

/*! returns error with aLocalizedDecription in kKTGenericErrorDomain with KTGenericError code */
+ (id)errorWithLocalizedDescription:(NSString *)aLocalizedDescription;

/*! messages NSApp to presentError: of aLocalizedDescription in kKTGenericErrorDomain with KTGenericError code */
+ (void)presentErrorWithLocalizedDescription:(NSString *)aLocalizedDescription;

/*!	Returns an error for the given HTTP code; includes some explanation for common codes.
*/
+ (id) errorWithHTTPStatusCode:(int)aStatusCode URL:(NSURL *)aURL;

@end


// for reference

// from FoundationErrors.h
//enum {
//    // File system and file I/O related errors, with NSFilePathErrorKey or NSURLErrorKey containing path or URL
//    NSFileNoSuchFileError = 4,				    // Attempt to do a file system operation on a non-existent file
//    NSFileLockingError = 255,				    // Couldn't get a lock on file
//    NSFileReadUnknownError = 256,                           // Read error (reason unknown)
//    NSFileReadNoPermissionError = 257,                      // Read error (permission problem)
//    NSFileReadInvalidFileNameError = 258,                   // Read error (invalid file name)
//    NSFileReadCorruptFileError = 259,                       // Read error (file corrupt, bad format, etc)
//    NSFileReadNoSuchFileError = 260,                        // Read error (no such file)
//    NSFileReadInapplicableStringEncodingError = 261,        // Read error (string encoding not applicable) also NSStringEncodingErrorKey
//    NSFileReadUnsupportedSchemeError = 262,		    // Read error (unsupported URL scheme)
//    NSFileWriteUnknownError = 512,			    // Write error (reason unknown)
//    NSFileWriteNoPermissionError = 513,                     // Write error (permission problem)
//    NSFileWriteInvalidFileNameError = 514,                  // Write error (invalid file name)
//    NSFileWriteInapplicableStringEncodingError = 517,       // Write error (string encoding not applicable) also NSStringEncodingErrorKey
//    NSFileWriteUnsupportedSchemeError = 518,		    // Write error (unsupported URL scheme)
//    NSFileWriteOutOfSpaceError = 640,                       // Write error (out of disk space)
//	
//    // Other errors
//    NSKeyValueValidationError = 1024,                       // KVC validation error
//    NSFormattingError = 2048,                               // Formatting error
//    NSUserCancelledError = 3072,			    // User cancelled operation (this one often doesn't deserve a panel and might be a good one to special case)
//	
//    // Inclusive error range definitions, for checking future error codes
//    NSFileErrorMinimum = 0,
//    NSFileErrorMaximum = 1023,
//    
//    NSValidationErrorMinimum = 1024,
//    NSValidationErrorMaximum = 2047,
//	
//    NSFormattingErrorMinimum = 2048,
//    NSFormattingErrorMaximum = 2559
//};

// from AppKitErrors.h
//enum {
//    NSTextReadInapplicableDocumentTypeError = 65806,		// NSAttributedString parsing error
//    NSTextWriteInapplicableDocumentTypeError = 66062,		// NSAttributedString generating error
//	
//    // Inclusive error range definitions, for checking future error codes
//    NSTextReadWriteErrorMinimum = 65792,
//    NSTextReadWriteErrorMaximum = 66303
//};

// from CoreDataErrors.h
//enum {
//    NSManagedObjectValidationError                   = 1550,   // generic validation error
//    NSValidationMultipleErrorsError                  = 1560,   // generic message for error containing multiple validation errors
//    NSValidationMissingMandatoryPropertyError        = 1570,   // non-optional property with a nil value
//    NSValidationRelationshipLacksMinimumCountError   = 1580,   // to-many relationship with too few destination objects
//    NSValidationRelationshipExceedsMaximumCountError = 1590,   // bounded, to-many relationship with too many destination objects
//    NSValidationRelationshipDeniedDeleteError        = 1600,   // some relationship with NSDeleteRuleDeny is non-empty
//    NSValidationNumberTooLargeError                  = 1610,   // some numerical value is too large
//    NSValidationNumberTooSmallError                  = 1620,   // some numerical value is too small
//    NSValidationDateTooLateError                     = 1630,   // some date value is too late
//    NSValidationDateTooSoonError                     = 1640,   // some date value is too soon
//    NSValidationInvalidDateError                     = 1650,   // some date value fails to match date pattern
//    NSValidationStringTooLongError                   = 1660,   // some string value is too long
//    NSValidationStringTooShortError                  = 1670,   // some string value is too short
//    NSValidationStringPatternMatchingError           = 1680,   // some string value fails to match some pattern
//    
//    NSManagedObjectContextLockingError               = 132000, // can't acquire a lock in a managed object context
//    NSPersistentStoreCoordinatorLockingError         = 132010, // can't acquire a lock in a persistent store coordinator
//    
//    NSManagedObjectReferentialIntegrityError         = 133000, // attempt to fire a fault pointing to an object that does not exist (we can see the store, we can't see the object)
//    NSManagedObjectExternalRelationshipError         = 133010, // an object being saved has a relationship containing an object from another store
//    NSManagedObjectMergeError                        = 133020, // merge policy failed - unable to complete merging
//    
//    NSPersistentStoreInvalidTypeError                = 134000, // unknown persistent store type/format/version
//    NSPersistentStoreTypeMismatchError               = 134010, // returned by persistent store coordinator if a store is accessed that does not match the specified type
//    NSPersistentStoreIncompatibleSchemaError         = 134020, // store returned an error for save operation (database level errors ie missing table, no permissions)
//    NSPersistentStoreSaveError                       = 134030, // store returned an error for save operation (database level errors ie missing table, no permissions)
//    NSPersistentStoreIncompleteSaveError             = 134040  // one or more of the stores returned an error during save (stores/objects that failed will be in userInfo)
//};
