require File.join(File.dirname(__FILE__), 'bloominsimple')
require 'digest/sha1'

class WhatLanguage
  VERSION = '1.0.3'

  HASHER = lambda { |item| Digest::SHA1.digest(item.downcase.strip).unpack("VV") }

  BITFIELD_WIDTH = 2_000_000

  @@data = {}

  def initialize(options = {})
    Dir.entries(languages_folder).grep(/\.lang/).each do |lang|
      @@data[lang[/\w+/].to_sym] ||= BloominSimple.from_dump(File.new(File.join(languages_folder, lang), 'rb').read, &HASHER)
    end
  end

  # Very inefficient method for now.. but still beats the non-Bloom alternatives.
  # Change to better bit comparison technique later..
  def process_text(text, min_score = 4, check_every = 4)
    results = Hash.new(0)
    it = 0
    text.split.collect {|a| a.downcase }.each do |word|
      it += 1
      @@data.keys.each do |lang|
        results[lang] += 1 if @@data[lang].includes?(word)
      end

      # Every now and then check to see if we have a really convincing result.. if so, exit early.
      if it % min_score == 0 && results.size > 1
        top_results = results.sort_by{|a,b| b}.reverse[0..1]

        # Next line may need some tweaking one day..
        break if top_results[0][1] > check_every && ((top_results[0][1] > top_results[1][1] * 2) || (top_results[0][1] - top_results[1][1] > 25))
      end

      #break if it > 100
    end
    results
  end

  def language(text)
    process_text(text).max { |a,b| a[1] <=> b[1] }.first rescue nil
  end

  def languages_folder
    self.class.languages_folder
  end

  def self.languages_folder
    folder = File.join(File.dirname(__FILE__), "..", "lang")
  end

  def self.filter_from_dictionary(filename)
    bf = BloominSimple.new(BITFIELD_WIDTH, &HASHER)
    File.open(filename).each { |word| bf.add(word) }
    bf
  end

  def self.wordlists_folder
    File.join(File.dirname(__FILE__), "..", "wordlists")
  end

  def self.wordlist_filename(lang)
    "#{ wordlists_folder }/#{ lang }"
  end

  def self.open_wordlist(lang, flags, &block)
    File.open(wordlist_filename(lang), flags, &block)
  end

  def self.in_wordlist?(word, lang)
    open_wordlist(lang, 'r') do |f|
      f.any? do |line|
        line.include?(word)
      end
    end
  end

  def self.learn(string, lang)
    words = string.split.map {|s| s.gsub /[^[[:word:]]]/, '' }.uniq
    words.each do |word|
      unless in_wordlist?(word, lang)
        puts "#{word} not found in #{lang}"
        open_wordlist(lang, 'a') do |wordlist|
          wordlist.puts word
        end
      end
    end

    filter = WhatLanguage.filter_from_dictionary(File.join(wordlists_folder, lang.to_s))
    File.open(File.join(languages_folder, lang.to_s + ".lang"), 'wb') { |f| f.write filter.dump }
  end
end

class String
  def language
    WhatLanguage.new(:all).language(self)
  end
end
