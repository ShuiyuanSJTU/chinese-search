# frozen_string_literal: true

# name: chinese-search
# version: 0.4
# authors: chenyxuan
# url: https://github.com/ShuiyuanSJTU/chinese-search

after_initialize do

  module OverridingPrepareData
    def prepare_data(search_data, purpose = :nil)
      data = search_data.dup
      data.force_encoding("UTF-8")
      if purpose != :topic
        # TODO cppjieba_rb is designed for chinese, we need something else for Japanese
        # Korean appears to be safe cause words are already space seperated
        # For Japanese we should investigate using kakasi
        if segment_cjk?
          require 'cppjieba_rb' unless defined? CppjiebaRb
          # mainly difference from original
          if purpose == :query
            data = CppjiebaRb.segment(search_data, mode: :mix)
          else
            data = CppjiebaRb.segment(search_data, mode: :mix) + CppjiebaRb.segment(search_data, mode: :full)
          end

          # TODO: we still want to tokenize here but the current stopword list is too wide
          # in cppjieba leading to words such as volume to be skipped. PG already has an English
          # stopword list so use that vs relying on cppjieba
          if ts_config != 'english'
            data = CppjiebaRb.filter_stop_word(data)
          else
            data = data.filter { |s| s.present? }
          end

          data = data.join(' ')

        else
          data.squish!
        end

        if SiteSetting.search_ignore_accents
          data = strip_diacritics(data)
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
