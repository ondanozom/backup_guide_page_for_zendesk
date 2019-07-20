#!/usr/bin/ruby

require 'json'
require 'date'
require 'kconv'
require "fileutils"
require "erb"
require 'yaml'
Encoding.default_external = "utf-8"

$exec_index = 0
$users = {}

# 定数
$FILE_CONFIG = "config.yml"
$DIR_TEMP = "../temp"
$DIR_OUT = "../output"
$DIR_ERB = "../erb" 

$API_GET_CATEGORIES = "api/v2/help_center/categories.json?sort_by=position&sort_order=asc"
$API_GET_SECTIONS = "api/v2/help_center/sections.json?sort_by=position&sort_order=asc"
$API_GET_ARTICLES = "api/v2/help_center/articles.json?sort_by=position&sort_order=asc"

# グローバル変数
$yaml = YAML.load_file($FILE_CONFIG)

# バッチ引数
exec_type = ARGV[0].to_i

puts "exec_type => #{exec_type}"

module ExecType
  STACA  = 1 # ExecTypeを増やして複数のサイトから取得も可能
end





module ExecType
  def self.all
    self.constants.map{|name| self.const_get(name) }
  end
end

#
# UTC日時フォーマット(ex.20114-12-26T08:04:22Z) を 日本時間に変換する
#  フォーマット変換エラーは起きないだろうから、rescueしない
def format_date(dt_str) 
  in_format = '%Y-%m-%dT%H:%M:%SZ'
  out_format = '%Y/%m/%d %H:%M:%S'
  format_date2(dt_str, in_format, out_format)
end
def format_date2(dt_str, in_format, out_format) 
  local = DateTime.now
  date = DateTime.strptime(dt_str, in_format)
  #date = date + 9*60*60 # 9時間加算する(UTC-->JST)
  local_date = date.new_offset(local.offset)
  return local_date.strftime(out_format)
end

# email設定ファイルより読み取る
def get_email()
  email = ""
  f = open("e-mail.txt", "r")
  while line = f.gets
    if line.toutf8 =~ /(.+?@.+)/
      email = $1
      break
    end
  end
  f.close
  return email
end

#
# カテゴリを取得する
#
def get_categories(url, user)
  temp = "categories.tmp"
  j = nil
  `curl "#{url}" -u #{user} > #{temp}`
  open(temp) { |io|
    j = JSON.load(io)
  }
  FileUtils.rm(temp)
  return j['categories']
end

#
# セクションを取得する
#
def get_sections(url, user)
  temp = "sections.tmp"
  sections = []
  j = nil
  while url =~ /https\:\/\/.+\.zendesk\.com\/api/ do
    `curl "#{url}" -u #{user} > #{temp}`
    open(temp) { |io|
      j = JSON.load(io)
      sections.concat(j['sections']) # concat:配列に配列を結合
      if j['next_page'] =~ /https\:\/\/.+\.zendesk\.com\/api/ then
        url = j['next_page']
      else
	url = nil
      end
    }
  end
  FileUtils.rm(temp)
  return sections
end

#
# zendeskよりjsonファイルを取得する
#
def get_articles(url, user, file)
  file_count = 0

  while url =~ /https\:\/\/.+\.zendesk\.com\/api/ do

    # jsonファイル名
    file_count += 1
    json_file = "#{file}_#{file_count}.txt"

    # jsonファイルを取得（作成）する
    #`curl -k -u #{user} "#{url}" > #{json_file}` win -> curl.exe の場合
    `curl "#{url}" -u #{user} > #{json_file}`

    open(json_file) { | io |
      j = JSON.load(io)
      # next_pageが存在するかチェックする
      if j['next_page'] =~ /https\:\/\/.+\.zendesk\.com\/api/ then
        url = j['next_page']
      else
        url = nil
      end
    }
  end

end

#
# HTMLファイルを出力
#
def output_html(folder, categories, sections, inputfile, outputfile)
  # ローカルのJSONファイルを読み込む
  json_files = Dir::glob("#{inputfile}*.txt")

  backupfile_count = 0
  backup_datetime = Time.now.strftime("%Y-%m-%d %H:%M")
  data_ary = []

  json_files.each {|in_file|
  # ファイル数分繰り返し
    json_data = open(in_file) {|io|
      j = JSON.load(io)
      j['articles'].each {|t|
        line = {}
	line['id'] = t['id']
	line['html_url'] = t['html_url']
	line['title'] = t['title']
	line['draft'] = t['draft']
	line['created_at'] = format_date(t['created_at'])
	line['updated_at'] = format_date(t['updated_at'])
	line['backup_filename'] = "#{t['id']}.html.txt"
	line['folder'] = folder

	# セクションを検索
	section = sections.find {|s| s['id'] == t['section_id']}
	if section != nil then
	  line['section_id'] = section['id']
	  line['section_url'] = section['html_url']
          line['section_name'] = section['name']
	  category = categories.find {|c| c['id'] == section['category_id']}
	  if category != nil then
            line['category_id'] = category['id'] 
            line['category_url'] = category['html_url'] 
            line['category_name'] = category['name']
	  end
	end

	# 記事をバックアップする
        open("#{outputfile}/#{line['backup_filename']}", "w") {|o|
          o.puts t['body']
        }

	data_ary << line
        backupfile_count += 1
      } # t
    } # io
  } # in_file
  $result_msg << "#{outputfile} にバックアップを作成しました（#{backupfile_count} ファイル）..."
  
  # カテゴリID,セクションID昇順にソート
  data_ary.sort_by!{|d| [d['category_id'],d['section_id']]}
  
  # index HTML の作成
  html_erb = ERB.new(File.read("#{$DIR_ERB}/template.html.erb"),nil,'-')
  html_file = "#{outputfile}/../articles_index.html"
  open(html_file, "w") {|o|
    o.puts(html_erb.result(binding))
  }
  $result_msg << "#{html_file} を作成しました。"
  
  # index CSV の作成
  csv_file = "#{outputfile}/../articles_index.csv"
  File.open(csv_file, 'w') do |wfile|
  # header
    h_arr = ["No.","カテゴリ名","セクション名","記事ID","下書き","タイトル","URL","作成日時","更新日時"]
    wfile.puts h_arr.join(",")
  # body
  data_ary.each.with_index(1) do | line, i |
    arr = []
    arr << i
    arr << line['category_name']
    arr << line['section_name']
    arr << line['id']
    arr << (line['draft'] ? "■" :  "")
    arr << line['title']
    arr << line['html_url']
    arr << line['created_at']
    arr << line['updated_at']
    wfile.puts arr.map{|i| i.to_s}.join(",")
  end
end
  $result_msg << "#{csv_file} を作成しました。"
  
end



#
# main
#
$result_msg = []

# バックアップ日時をセット
now = Time.now
backup_ymdhm = now.strftime("%Y%m%d%H%M")

# 設定をロード
p $yaml['domain'] 

# フォルダがなかったら作る
FileUtils.mkdir_p("#{$DIR_TEMP}") unless FileTest.exist?("#{$DIR_TEMP}")
FileUtils.mkdir_p("#{$DIR_OUT}") unless FileTest.exist?("#{$DIR_OUT}")

# 以前の作業ファイルを削除する
FileUtils.rm(Dir.glob("#{$DIR_TEMP}/*"))
#FileUtils.rm(Dir.glob("#{$DIR_OUT}/*"))


# 実行する種別
exec_que = []
if 1 <= exec_type && exec_type <= 13 then
  exec_que = [exec_type]
else
  exec_que = ExecType.all # 上記以外が指定された場合はALL
end


for i in exec_que do

  $exec_index = i
  folder = $yaml['folder'] 
  puts "-------------------------------"
  p "バックアップを開始します..."
  puts "-------------------------------"

  user = "#{$yaml['account']}/token:#{$yaml['token']}"
  
  # カテゴリを取得する
  categories_url = "#{$yaml['domain'] }#{$API_GET_CATEGORIES}"
  categories = get_categories(categories_url, user)

  # セクションを取得する
  sections_url = "#{$yaml['domain'] }#{$API_GET_SECTIONS}"
  sections = get_sections(sections_url, user)

  # FAQページを取得する
  articles_url = "#{$yaml['domain']}#{$API_GET_ARTICLES}"
  file = "#{$DIR_TEMP}/articles_json"
  get_articles(articles_url, user, file)

  # FAQファイルを出力する
  output_file = "#{$DIR_OUT}/#{backup_ymdhm}/#{folder}" 
  FileUtils.rm_rf(output_file) if FileTest.exist?(output_file)
  FileUtils.mkdir_p(output_file) unless FileTest.exist?(output_file)
  output_html(folder, categories, sections, file, output_file)
  
end

puts "-------------------------------"
puts $result_msg.join("\r\n")

# copyright: nozomu.onda@street-academy.com, Tokyo, Japan
