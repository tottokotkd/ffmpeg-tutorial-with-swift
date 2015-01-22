//
//  Tutorial1.swift
//  Tutorials
//
//  Created by Tokuda Shusuke on 2015/01/22.
//  Copyright (c) 2015年 Tokuda Shusuke. All rights reserved.
//

import Foundation

typealias SwsContext = COpaquePointer

class Tutorial1 {
    /**
    PPM形式で保存する
    */
    func saveAsPPM(frame: UnsafePointer<AVFrame>, filePath: String, width: Int, height: Int) -> Bool {
        // ファイルを開く
        var file = fopen(filePath.cStringUsingEncoding(NSUTF8StringEncoding)!, "wb")
        if file == nil { return false }
        
        // ヘッダーを書き込む
        let header = "P6\n\(width) \(height)\n255\n"
        fwrite(header.cStringUsingEncoding(NSUTF8StringEncoding)!, 1, UInt(countElements(header)), file)
        
        // ピクセルデータを書き込む
        for i in 0..<height {

            
            let y = UnsafeBufferPointer(start: frame.memory.data.0 + i * Int(frame.memory.linesize.0), count: width * 3)
            fwrite(y.baseAddress, 1, UInt(width * 3), file)
        }
        if fclose(file) != 0 {
            return false
        }
        return true
    }
    
    /**
    映像をデコードする
    */
    func decodeVideo(codecContext: UnsafeMutablePointer<AVCodecContext>, frame: UnsafeMutablePointer<AVFrame>, packet: UnsafeMutablePointer<AVPacket>) -> Bool {
        var finished = UnsafeMutablePointer<Int32>.alloc(1)
        avcodec_decode_video2(codecContext, frame, finished, packet)
        return finished.memory.bool
    }
    
    /**
    sws_scaleを実行する
    
    :param: option SwsContextの設定を入力したSwsContextOptionインスタンス
    :param: source 変換前のフレーム
    :param: target 変換後のフレーム: バッファーを持っていなければならない！
    :returns:
    */
    func swsScale(option: SwsContext, source: UnsafePointer<AVFrame>, target: UnsafePointer<AVFrame>, height: Int32) -> Int {
        
        let sourceData = [
            UnsafePointer<UInt8>(source.memory.data.0),
            UnsafePointer<UInt8>(source.memory.data.1),
            UnsafePointer<UInt8>(source.memory.data.2),
            UnsafePointer<UInt8>(source.memory.data.3),
            UnsafePointer<UInt8>(source.memory.data.4),
            UnsafePointer<UInt8>(source.memory.data.5),
            UnsafePointer<UInt8>(source.memory.data.6),
            UnsafePointer<UInt8>(source.memory.data.7),
        ]
        let sourceLineSize = [
            source.memory.linesize.0,
            source.memory.linesize.1,
            source.memory.linesize.2,
            source.memory.linesize.3,
            source.memory.linesize.4,
            source.memory.linesize.5,
            source.memory.linesize.6,
            source.memory.linesize.7
        ]
        
        let targetData = [
            target.memory.data.0,
            target.memory.data.1,
            target.memory.data.2,
            target.memory.data.3,
            target.memory.data.4,
            target.memory.data.5,
            target.memory.data.6,
            target.memory.data.7
        ]
        let targetLineSize = [
            target.memory.linesize.0,
            target.memory.linesize.1,
            target.memory.linesize.2,
            target.memory.linesize.3,
            target.memory.linesize.4,
            target.memory.linesize.5,
            target.memory.linesize.6,
            target.memory.linesize.7
        ]
        let result = sws_scale(
            option,
            sourceData,
            sourceLineSize,
            0,
            height,
            targetData,
            targetLineSize
        )
        return Int(result)
    }
    
    func main(filePath: String) {
        // フォーマット・コーデックを登録
        av_register_all()
        
        // ファイルを開く
        var formatContext  = UnsafeMutablePointer<AVFormatContext>()
        if avformat_open_input(&formatContext, filePath, nil, nil) != 0 {
            println("Couldn't open file")
            return
        }
        
        // ストリームの情報を得る
        if avformat_find_stream_info(formatContext, nil) < 0 {
            println("Couldn't find stream information")
            return
        }
        
        // 入力ファイルのフォーマット情報をstderrに出力する
        av_dump_format(formatContext, 0, filePath, false.c)

        // 最初の映像ストリームを探す
        let target = AVMEDIA_TYPE_VIDEO
        var avStream: UnsafeMutablePointer<AVStream>? = nil
        var n = -1
        
        for i in 0..<Int(formatContext.memory.nb_streams) {
            let s = formatContext.memory.streams[i]
            if s.memory.codec.memory.codec_type.value == target.value {
                avStream = s
                n = i
            }
        }
        if avStream == nil {
            println("Didn't find a video stream")
            return
        }
        
        // コーデック・コンテキストのポインターを取得
        let codecContext = formatContext.memory.streams[n].memory.codec
        
        // 映像ストリームのデコーダーを探す
        let codec = avcodec_find_decoder(codecContext.memory.codec_id)
        if codec == nil {
            println("Unsupported codec")
            return
        }
        
        // コーデックを開く
        if avcodec_open2(codecContext, codec, nil) < 0 {
            println("Could not open codec")
            return
        }
        
        // 映像フレームのためにメモリーを確保する
        var frame = av_frame_alloc()
        var convertedFrame = av_frame_alloc()
        if frame == nil || convertedFrame == nil {
            return
        }
        
        // 変換後のフレームのために必要なバッファーを確保する
        let w = codecContext.memory.width
        let h = codecContext.memory.height
        let format = PIX_FMT_BGR24
        let size = avpicture_get_size(PIX_FMT_BGR24, w, h)
        var buffer = [UInt8](count: Int(size), repeatedValue: 0)
        
        // フレームにバッファーを割り当てる
        avpicture_fill(UnsafeMutablePointer<AVPicture>(convertedFrame), UnsafePointer<UInt8>(buffer), format, w, h)
        
        // パケットを用意
        var packet = UnsafeMutablePointer<AVPacket>.alloc(1)
        
        // フレームを読み込む
        var i = 0
        while av_read_frame(formatContext, packet) >= 0  {
            // 対象ストリームからのパケットであることを確認
            if packet.memory.stream_index == Int32(n) {
                // パケットに保存したデータから映像フレームをデコードできたら実行
                if decodeVideo(codecContext, frame: frame, packet: packet) {
                    
                    // 画像をRGB形式に変換。サイズはデフォルト (ソースと同じ)
                    let swsContextOption = sws_getContext(
                        codecContext.memory.width,
                        codecContext.memory.height,
                        codecContext.memory.pix_fmt,
                        w, h, PIX_FMT_RGB24, SWS_BILINEAR, nil, nil, nil)
                    swsScale(swsContextOption, source: frame, target: convertedFrame, height: h)
                    
                    // 100フレームごとに1つ保存
                    if ++i % 100 == 0 {
                        saveAsPPM(convertedFrame, filePath: "/Users/tottokotkd/frame\(i).ppm", width: Int(w), height: Int(h))
                    }
                }
            }
            // av_read_frame() で得られたパケット分のメモリーを開放
            av_free_packet(packet)
        }
        
        // フレームのメモリーを開放する
        av_frame_free(&frame)
        av_frame_free(&convertedFrame)
        
        // コーデックを閉じる
        avcodec_close(codecContext)
        
        // 動画ファイルを閉じる
        avformat_close_input(&formatContext)
    }
}