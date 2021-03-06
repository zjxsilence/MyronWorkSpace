//
//  Video.m
//  iFrameExtractor
//
//  Created by lajos on 1/10/10.
//  Copyright 2010 www.codza.com. All rights reserved.
//

#import "VideoFrameExtractor.h"
#include "avformat.h"
#include "swscale.h"
#include "libavutil/time.h"

@interface VideoFrameExtractor () {
    AVFormatContext *pFormatCtx;
    AVCodecContext *pCodecCtx;
    AVFrame *pFrame;
    AVPacket packet;
    AVPicture picture;
    int videoStream;
    struct SwsContext *img_convert_ctx;
    int sourceWidth, sourceHeight;
    int outputWidth, outputHeight;
    UIImage *currentImage;
    double duration;
    double currentTime;
    int64_t pts;
    BOOL miss;
}

-(BOOL)convertFrameToRGB;

-(UIImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height;

-(void)setupScaler;

@end

@implementation VideoFrameExtractor

@synthesize outputWidth, outputHeight;

-(void)setOutputWidth:(int)newValue {
    if (outputWidth == newValue) return;
    outputWidth = newValue;
    [self setupScaler];
}

-(void)setOutputHeight:(int)newValue {
    if (outputHeight == newValue) return;
    outputHeight = newValue;
    [self setupScaler];
}

-(UIImage *)currentImage {
    if (!pFrame->data[0]) return nil;
    if ( [self convertFrameToRGB] ) {
        UIImage * image = [self imageFromAVPicture:picture width:outputWidth height:outputHeight];
        if (image) {
            av_free_packet(&packet);
        }
        return image;
    } else {
        av_free_packet(&packet);
        return nil;
    }
}

-(double)duration {
    return (double)pFormatCtx->duration / AV_TIME_BASE;
}

- (float)fps {
    // 获取帧率
    AVRational fps = pFormatCtx->streams[videoStream]->r_frame_rate;
    return  (float)fps.num / (float)fps.den;
}

-(double)currentTime {
    
    AVRational timeBase = pFormatCtx->streams[videoStream]->time_base;
    double time = (double)packet.pts * (double)timeBase.num / (double)timeBase.den;
    
    return time;
}

-(int)sourceWidth {
    return pCodecCtx->width;
}

-(int)sourceHeight {
    return pCodecCtx->height;
}

-(id)initWithVideo:(NSString *)moviePath {
    if (moviePath==nil||moviePath.length==0)return nil;
    if (!(self=[super init])) return nil;
    
    AVCodec         *pCodec;
    
    // Register all formats and codecs
    avcodec_register_all();
    av_register_all();
    
    // Open video file
    avformat_network_init();
    if(avformat_open_input(&pFormatCtx, [moviePath cStringUsingEncoding:NSASCIIStringEncoding], NULL, NULL) != 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't open file\n");
        goto initError;
    }
    
    // Retrieve stream information
    if(avformat_find_stream_info(pFormatCtx, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't find stream information\n");
        goto initError;
    }
    
    // Find the first video stream
    if ((videoStream =  av_find_best_stream(pFormatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &pCodec, 0)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot find a video stream in the input file\n");
        goto initError;
    }
    
    // Get a pointer to the codec context for the video stream
    pCodecCtx = pFormatCtx->streams[videoStream]->codec;
    
    
    // Find the decoder for the video stream
    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
    if(pCodec == NULL) {
        av_log(NULL, AV_LOG_ERROR, "Unsupported codec!\n");
        goto initError;
    }
    
    // Open codec
    if(avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot open video decoder\n");
        goto initError;
    }
    
    // Allocate video frame
    pFrame = av_frame_alloc();
    
    outputWidth = pCodecCtx->width;
    self.outputHeight = pCodecCtx->height;
    
    return self;
    
initError:
    return nil;
}


-(void)setupScaler {
    
    // Release old picture and scaler
    avpicture_free(&picture);
    sws_freeContext(img_convert_ctx);
    
    // Allocate RGB picture
    avpicture_alloc(&picture, AV_PIX_FMT_RGB24, outputWidth, outputHeight);
    
    // Setup scaler
    static int sws_flags =  SWS_FAST_BILINEAR;
    
    img_convert_ctx = sws_getCachedContext(NULL,
                                           pCodecCtx->width, pCodecCtx->height, pCodecCtx->pix_fmt,
                                           outputWidth, outputHeight, AV_PIX_FMT_RGB24,
                                           sws_flags, NULL, NULL, NULL);
}

-(BOOL)seekTime:(double)seconds {
    
    AVRational timeBase = pFormatCtx->streams[videoStream]->time_base;
    int64_t targetFrame = (int64_t)((double)timeBase.den / timeBase.num * seconds);
    int flag = avformat_seek_file(pFormatCtx, videoStream, targetFrame, targetFrame, targetFrame, AVSEEK_FLAG_FRAME);
    avcodec_flush_buffers(pCodecCtx);
    
    if (flag >= 0) {
        [self setupScaler];
    }
    
    return flag >= 0;
}

-(void)dealloc {
    // Free scaler
    sws_freeContext(img_convert_ctx);
    
    // Free RGB picture
    avpicture_free(&picture);
    
    // Free the packet that was allocated by av_read_frame
    av_free_packet(&packet);
    
    // Free the YUV frame
    av_free(pFrame);
    
    // Close the codec
    if (pCodecCtx) avcodec_close(pCodecCtx);
    
    // Close the video file
    if (pFormatCtx) avformat_close_input(&pFormatCtx);
    
    NSLog(@"frame dealloc");
}

-(BOOL)isMiss {
    return miss;
}

-(BOOL)stepFrame {
    // AVPacket packet;
    int frameFinished=0;
    
    
    //NSLog(@"key_frame %d, pts %lld, self.pts %lld, miss %d, pos: %llu, dts: %lld", pFrame->key_frame, packet.pts, pts, miss, packet.pos, packet.dts);
    
    if (pFrame->key_frame == 1) {
        miss = false;
    } else {
        if (packet.pts - pts != 3000) {
            miss = true;
        }
    }
    
    pts = packet.pts;
    while(!frameFinished && av_read_frame(pFormatCtx, &packet)>=0) {
        // Is this a packet from the video stream?
        if(packet.stream_index==videoStream) {
            // Decode video frame
            avcodec_decode_video2(pCodecCtx, pFrame, &frameFinished, &packet);
        }
    }
    return frameFinished!=0;
}

-(BOOL)convertFrameToRGB {
    if (img_convert_ctx && pFrame && pCodecCtx) {
        int flag = sws_scale (img_convert_ctx, (void*)pFrame->data, pFrame->linesize,
                   0, pCodecCtx->height,
                   picture.data, picture.linesize);
        return flag > 0;
    } else {
        return NO;
    }
}

-(UIImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height {
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, pict.data[0], pict.linesize[0]*height);
    //char * j = (char *)pict.data[0][0];
//    NSMutableString * tt = [[NSMutableString alloc] init];
//    for (int i = 0; i < pict.linesize[0]*height; i++) {
//        [tt appendString:[NSString stringWithFormat:@" %s", (char *)pict.data[0][i]]];
//    }
//    //NSLog(@"\n\n%hhu", pict.data[0][0]);
//    NSLog(@"\ntt\n\n%@\n\n\n", tt);
    
//    NSData * ddd = (__bridge NSData *)data;
    
    //NSLog(@"\n%@", ddd);
//    NSString * sss = [[NSString alloc] initWithUTF8String:data];
//    NSData * ddd = [sss dataUsingEncoding:NSUTF8StringEncoding];
//    NSString * time = [NSString stringWithFormat:@"/Users/Myron/Desktop/未命名文件夹/%f", [[NSDate alloc] init].timeIntervalSince1970];
//    [ddd writeToFile:time atomically:true];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width, height,
                                       8, 24, pict.linesize[0],
                                       colorSpace, bitmapInfo, provider,
                                       NULL, NO, kCGRenderingIntentDefault);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return image;
}

@end
