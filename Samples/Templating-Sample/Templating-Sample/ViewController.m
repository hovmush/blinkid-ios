//
//  ViewController.m
//  Templating-Sample
//
//  Created by Dino on 08/06/16.
//  Copyright © 2016 Dino. All rights reserved.
//

#import "ViewController.h"

@import MicroBlink;

@interface ViewController () <PPScanningDelegate>

@property (nonatomic, strong) NSString *nricNumber;
@property (nonatomic, strong) NSString *documentImageName;
@property (nonatomic, strong) UIImage *documentImage;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/**
 * Method allocates and initializes the Scanning coordinator object.
 * Coordinator is initialized with settings for scanning
 * Modify this method to include only those recognizer settings you need. This will give you optimal performance
 *
 *  @param error Error object, if scanning isn't supported
 *
 *  @return initialized coordinator
 */
- (PPCameraCoordinator *)coordinatorWithError:(NSError **)error {

    /** 0. Check if scanning is supported */

    if ([PPCameraCoordinator isScanningUnsupportedForCameraType:PPCameraTypeBack error:error]) {
        return nil;
    }


    /** 1. Initialize the Scanning settings */

    // Initialize the scanner settings object. This initialize settings with all default values.
    PPSettings *settings = [[PPSettings alloc] init];

    // tell which metadata you want to receive. Metadata collection takes CPU time - so use it only if necessary!
    settings.metadataSettings.dewarpedImage = YES; // get dewarped image of ID documents


    /** 2. Setup the license key */

    // Visit www.microblink.com to get the license key for your app
    settings.licenseSettings.licenseKey = @"Z6IRXYP2-ZTPVW6QN-JGIGNUUZ-MOA4ZXBP-NYMTPA3F-LTHWKXGP-MVOM7RMK-62PU3B3D";
    // License key is valid temporarily until 2018-01-18


    /**********************************************************************************************************************/
    /**************  For Detector Recognizer  **************/
    /**********************************************************************************************************************/


    /**
     * 3. Set up what is being scanned. See detailed guides for specific use cases.
     * Remove undesired recognizers (added below) for optimal performance.
     */
    {
        self.documentImageName = @"DocumentImage";

        PPDecodingInfo *info = [[PPDecodingInfo alloc] initWithLocation:CGRectMake(0.0f, 0.0f, 1.0f, 1.0f) dewarpedHeight:700.f uniqueId:self.documentImageName];

        /**
         * Create ID card document specification. Document specification defines geometric/scanning properties of documents to be detected
         */
        PPDocumentSpecification *idSpec = [PPDocumentSpecification newFromPreset:PPDocumentPresetId1Card];

        /**
         * Set decoding infos as our classification decoding infos. One has location of document number on old id, other on new Id
         */
        [idSpec setDecodingInfo:@[info]];

        /**
         * Wrap Document specification in detector settings
         */
        PPDocumentDetectorSettings *detectorSettings = [[PPDocumentDetectorSettings alloc] initWithNumStableDetectionsThreshold:4];
        [detectorSettings setDocumentSpecifications:@[ idSpec ]];


        PPDetectorRecognizerSettings *detectorRecognizerSettings = [[PPDetectorRecognizerSettings alloc] initWithDetectorSettings:detectorSettings];

        /**
         * Add decoding infos for classifier results. These infos and their parsers will only be processed if classifier outputs the
         * selected result
         */
        [settings.scanSettings addRecognizerSettings:detectorRecognizerSettings];
    }

    /**********************************************************************************************************************/
    /****************************************  BarcodeRecognizer ****************************************/
    /**********************************************************************************************************************/

    {
        PPBarcodeRecognizerSettings *barcodeRecognizerSettings = [[PPBarcodeRecognizerSettings alloc] init];

        barcodeRecognizerSettings.scanCode39 = YES;

        [settings.scanSettings addRecognizerSettings:barcodeRecognizerSettings];
    }


    /** 4. Initialize the Scanning Coordinator object */

    PPCameraCoordinator *coordinator = [[PPCameraCoordinator alloc] initWithSettings:settings delegate:nil];

    return coordinator;
}

- (IBAction)didTapScan:(id)sender {

    /** Instantiate the scanning coordinator */
    NSError *error;
    PPCameraCoordinator *coordinator = [self coordinatorWithError:&error];

    /** If scanning isn't supported, present an error */
    if (coordinator == nil) {
        NSString *messageString = [error localizedDescription];
        [[[UIAlertView alloc] initWithTitle:@"Warning"
                                    message:messageString
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil, nil] show];

        return;
    }

    // we reset the nric number
    self.nricNumber = nil;
    self.documentImage = nil;

    /** Create new scanning view controller */
    UIViewController<PPScanningViewController> *scanningViewController =
        [PPViewControllerFactory cameraViewControllerWithDelegate:self coordinator:coordinator error:nil];

    // allow rotation if VC is displayed as a modal view controller
    scanningViewController.autorotate = YES;
    scanningViewController.supportedOrientations = UIInterfaceOrientationMaskAll;

    /** Present the scanning view controller. You can use other presentation methods as well (instead of presentViewController) */
    [self presentViewController:scanningViewController animated:YES completion:nil];
}

#pragma mark - PPScanDelegate

- (void)scanningViewControllerUnauthorizedCamera:(UIViewController<PPScanningViewController> *)scanningViewController {
    // Add any logic which handles UI when app user doesn't allow usage of the phone's camera
}

- (void)scanningViewController:(UIViewController<PPScanningViewController> *)scanningViewController didFindError:(NSError *)error {
    // Can be ignored. See description of the method
}

- (void)scanningViewControllerDidClose:(UIViewController<PPScanningViewController> *)scanningViewController {

    // As scanning view controller is presented full screen and modally, dismiss it
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)scanningViewController:(UIViewController<PPScanningViewController> *)scanningViewController didOutputResults:(NSArray *)results {

    /**
     * Here you process scanning results. Scanning results are given in the array of PPRecognizerResult objects.
     * Each member of results array will represent one result for a single processed image
     * Usually there will be only one result. Multiple results are possible when there are 2 or more detected objects on a single image
     * (i.e. pdf417 and QR code side by side)
     */

    // first, pause scanning until we process all the results
    [scanningViewController pauseScanning];

    NSString *message = nil;
    NSString *title = nil;

    // Collect data from the result
    for (PPRecognizerResult *result in results) {

        if ([result isKindOfClass:[PPDetectorRecognizerResult class]] && self.nricNumber != nil && self.documentImage != nil) {

            /** This is where we handle the success case. We have everything we need */

            // self.nricNumber is the value of the NRIC number
            // self.documentImage is the image

            message = self.nricNumber;
            title = @"Scanning done";
        }

        if ([result isKindOfClass:[PPBarcodeRecognizerResult class]]) {
            PPBarcodeRecognizerResult *barcodeResult = (PPBarcodeRecognizerResult *)result;

            NSString *val = [barcodeResult stringUsingGuessedEncoding];

            if ([val length] == 9) {
                self.nricNumber = val;
            }
        }
    };

    if (message != nil && title != nil) {
        // present the alert view with scanned results
        UIAlertView *alertView =
            [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
    } else {
        [scanningViewController resumeScanningAndResetState:NO];
    }
}


- (void)scanningViewController:(UIViewController<PPScanningViewController> *)scanningViewController
             didOutputMetadata:(PPMetadata *)metadata {

    // Check if metadata obtained is image. You can set what type of image is outputed by setting different properties of PPMetadataSettings
    // (currently, dewarpedImage is set at line 57)
    if ([metadata isKindOfClass:[PPImageMetadata class]]) {

        PPImageMetadata *imageMetadata = (PPImageMetadata *)metadata;

        if ([[imageMetadata name] isEqualToString:self.documentImageName]) {
            self.documentImage = imageMetadata.image;
        }
    }
}

// dismiss the scanning view controller when user presses OK.
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
