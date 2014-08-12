//
//  ALAsset+ctn_Filters.h
//
//  Created by lingye on 8/11/14.
//  i.foxling@gmail.com
//

#import "ALAsset+ctn_Filters.h"

@implementation ALAsset (ctn_Filters)

- (UIImage *)ctn_imageByAppliedFilters {

    ALAssetRepresentation *repObj = self.defaultRepresentation;
    UIImage *fullImage = [UIImage imageWithCGImage:[repObj fullResolutionImage]
                                             scale:[repObj scale]
                                       orientation:(UIImageOrientation)repObj.orientation];

    NSDictionary *meta = repObj.metadata;
    NSString *adjustmentXMP = meta[@"AdjustmentXMP"];
    if (!IS_EMPTY_STRING(adjustmentXMP)) {
        NSData *adjustmentXMPData = [adjustmentXMP dataUsingEncoding:NSUTF8StringEncoding];

        CIContext *context = [CIContext contextWithOptions:nil];
        CIImage *image = nil;

        NSMutableArray *filters = [NSMutableArray arrayWithArray:[CIFilter filterArrayFromSerializedXMP:adjustmentXMPData
                                                                                       inputImageExtent:(CGRect){0, 0, repObj.dimensions} error:nil]];
        if (filters.count > 0) {

            CGFloat limitSide = context.inputImageMaximumSize.width;
            CGFloat fullImageLongSide = MAX(fullImage.size.width, fullImage.size.height);
            CGFloat ratio = 1;
            if (fullImageLongSide > limitSide) {
                ratio = 1600 / fullImageLongSide;
                @autoreleasepool {
                    CGImageRef imageRef = fullImage.CGImage;

                    int width = CGImageGetWidth(imageRef)   * ratio;
                    int height = CGImageGetHeight(imageRef) * ratio;

                    CGColorSpaceRef colorspace = CGImageGetColorSpace(imageRef);
                    CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height,
                                                                 CGImageGetBitsPerComponent(imageRef),
                                                                 CGImageGetBytesPerRow(imageRef),
                                                                 colorspace,
                                                                 CGImageGetBitmapInfo(imageRef));
                    CGColorSpaceRelease(colorspace);


                    CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), imageRef);
                    CGImageRef newImageRef = CGBitmapContextCreateImage(bitmap);
                    CGContextRelease(bitmap);

                    fullImage = [UIImage imageWithCGImage:newImageRef scale:fullImage.scale orientation:fullImage.imageOrientation];
                    CGImageRelease(newImageRef);
                }
            }

            image = [CIImage imageWithCGImage:fullImage.CGImage];

            while (filters.count > 0) {
                @autoreleasepool {
                    CIFilter *filter = filters.firstObject;
                    [filter setValue:image forKey:kCIInputImageKey];

                    if (ratio != 1) {
                        if ([filter.name isEqualToString:@"CICrop"]) {
                            CIVector *v = [filter valueForKey:@"inputRectangle"];
                            CIVector *newV = [CIVector vectorWithX:floorf(v.X * ratio) Y:floorf(v.Y * ratio) Z:floorf(v.Z * ratio) W:floorf(v.W * ratio)];
                            [filter setValue:newV forKey:@"inputRectangle"];
                        }

                        if ([filter.name isEqualToString:@"CIAffineTransform"]) {
                            CGAffineTransform t = [[filter valueForKey:kCIInputTransformKey] CGAffineTransformValue];
                            t.tx = floorf(t.tx * ratio);
                            t.ty = floorf(t.ty * ratio);
                            [filter setValue:[NSValue valueWithCGAffineTransform:t] forKey:kCIInputTransformKey];
                        }
                    }

                    image = [filter outputImage];
                    [filters removeObject:filter];
                }
            }
        }

        if (image != nil) {
            CGImageRef fullResolutionImage = [context createCGImage:image fromRect:image.extent];
            fullImage = [UIImage imageWithCGImage:fullResolutionImage scale:fullImage.scale orientation:fullImage.imageOrientation];
            CGImageRelease(fullResolutionImage);
        }
    }

    return fullImage;
}

@end
