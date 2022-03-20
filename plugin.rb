# frozen_string_literal: true

# name: chinese-search
# version: 0.4
# authors: chenyxuan
# url: https://github.com/ShuiyuanSJTU/chinese-search

after_initialize do

  module OverridingPrepareData
    def prepare_data(search_data, purpose = nil)
      data = search_data.dup
      data.force_encoding("UTF-8")
  
      if purpose != :topic
        if segment_chinese?
          require 'cppjieba_rb' unless defined? CppjiebaRb
  
          segmented_data = []
  
          # We need to split up the string here because Cppjieba has a bug where text starting with numeric chars will
          # be split into two segments. For example, '123abc' becomes '123' and 'abc' after segmentation.
          data.scan(/(?<chinese>[\p{Han}。,、“”《》…\.:?!;()]+)|([^\p{Han}]+)/) do
            match_data = $LAST_MATCH_INFO
  
            if match_data[:chinese]
              # mainly difference from original below
              if purpose == :query
                segments = CppjiebaRb.segment(match_data.to_s, mode: :mix)
              else
                segments = CppjiebaRb.segment(match_data.to_s, mode: :mix) + CppjiebaRb.segment(match_data.to_s, mode: :full)
              end
              # mainly difference from original above
  
              if ts_config != 'english'
                segments = CppjiebaRb.filter_stop_word(segments)
              end
  
              segments = segments.filter { |s| s.present? }
              segmented_data << segments.join(' ')
            else
              segmented_data << match_data.to_s.squish
            end
          end
  
          data = segmented_data.join(' ')
        elsif segment_japanese?
          data.gsub!(japanese_punctuation_regexp, " ")
          data = TinyJapaneseSegmenter.segment(data)
          data = data.filter { |s| s.present? }
          data = data.join(' ')
        else
          data.squish!
        end
      end
  
      data.gsub!(/\S+/) do |str|
        if str =~ /^["]?((https?:\/\/)[\S]+)["]?$/
          begin
            uri = URI.parse(Regexp.last_match[1])
            uri.query = nil
            str = uri.to_s
          rescue URI::Error
            # don't fail if uri does not parse
          end
        end
  
        str
      end
  
      data
    end
  end

  class ::Search
    singleton_class.prepend OverridingPrepareData
  end
end
