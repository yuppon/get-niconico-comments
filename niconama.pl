use strict;
use WWW::Mechanize;
use LWP::UserAgent;
use HTTP::Cookies;
use URI::Escape;
use HTTP::Request;
use HTTP::Headers;
use IO::Socket;
use IO::Select;
use XML::Simple;
use LWP::Simple;
use Data::Dumper;
use Encode;
use Encode::Guess qw/ euc-jp shiftjis 7bit-jis /;

# 初期設定

my $video_id = "lvからはじまるvideoID";
my $mail = 'address';
my $password = 'pass';
my $mech = WWW::Mechanize->new();


#ログイン
$mech->get( "https://secure.nicovideo.jp/secure/login_form" );
my $r = $mech->submit_form(
	form_name=>'',
	fields => {
		mail => $mail,
		password => $password,
	},
);

my $res = $mech->get( "http://live.nicovideo.jp/api/getplayerstatus?v=$video_id");
$\ ="\n";
my $content = uri_unescape($res->content);
die "放送してません" unless $content=~m!(.*)(\d*)(\d*)!;
my ($server,$port,$thread_id)=($1,$2,$3);

#XMLをパース
 my $document = LWP::Simple::get("http://live.nicovideo.jp/api/getplayerstatus?v=$video_id") ;
my $parser = XML::Simple->new;
my $data = $parser->XMLin($content);
$port = $data->{ms}->{port};
$server = $data->{ms}->{addr};
$thread_id = $data->{ms}->{thread};

#print "port:$port";
#print "addr:$server";
#print "thread:$thread_id";

# postデータ作成/準備
my $post_data = "<thread res_from=\"-100\" version=\"20061206\" thread=\"$thread_id \" />\0";
my $selecter = IO::Select->new;             

# 各サーバのソケットを生成
my $sock = IO::Socket::INET->new("$server:$port");
#print Dumper $sock;


# ソケットの追加
$selecter->add($sock); 
my $sock2host = "$server:$port";
print $sock $post_data;  
$sock->flush();
my $continue = 1;
# 読み込みが完了していないソケットが残っていたら
while ( $continue  == 1){
	my ($readable_socks) = IO::Select->select($selecter, undef, undef, undef);

	# 読み込み可能なソケットがあれば、以下の foreach ループが実行される
	foreach my $sock (@$readable_socks){
		my $len = sysread($sock, my($buf), 4096);   # ソケットから 4096 バイト読み込む
		my $comment = "read $len bytes from $sock2host\n $buf…";
		Encode::from_to($comment, 'Guess', 'utf8');
		print $comment;
		if ( $buf=~/\/disconnect/){
			print "放送終了： $sock2host\n";  # そのソケットからの読み込みは終了
			$selecter->remove($sock);         # select の対象から外す
			$sock->close();                   # ソケットをクローズ
			$continue=0;
		}
	}
}
