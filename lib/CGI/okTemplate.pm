package CGI::okTemplate;

use 5.008004;
use strict;
use Carp;
use English;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use CGI::okTemplate ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.02';


# Preloaded methods go here.

sub new {
	my $class = shift;
	my $self = {};

	bless($self,$class);
	$self->{___params} = {@_};
	$self->{___params}->{BlockTag} = 'TemplateBlock' unless $self->{___params}->{BlockTag};
	$self->{___params}->{RootDir} = `pwd` unless $self->{___params}->{RootDir};
	chomp $self->{___params}->{RootDir};
	$self->{___params}->{RootDir} .= '/';
	$self->{___params}->{RootDir} =~ s!//!/!g;
	confess "Root Dir have to be start with symbol '/'\n" unless ($self->{___params}->{RootDir} =~ /^\//);
	confess "Root Dir '$self->{___params}->{RootDir}' does not exists\n" unless (-d $self->{___params}->{RootDir});
	$self->read_template($self->{___params}->{File}) if($self->{___params}->{File});

	return $self;
}

sub read_template {
	my $self = shift;
	my $file = shift;
	$file = $self->{___params}->{File} unless ($file);

	$file =~ s![^/]+/\.\./!/!g;
	$file =~ s!/\.\./!/!g;

	confess "File '$self->{___params}->{RootDir}$file' does not exists\n" unless (-r "$self->{___params}->{RootDir}$file");
	local($/) = undef;
	open IN, "$self->{___params}->{RootDir}$file";
	my $in = <IN>;
	close IN;
	my $cur_path = "$self->{___params}->{RootDir}$file";
	$cur_path =~ s/[^\/]*$//;
	$cur_path =~ s!//!/!g;
	$in = ___read_includes($in,$cur_path,$self->{___params}->{RootDir});
	$self->{___template___} = ___parse_template($in,$self->{___params}->{BlockTag},$cur_path,$self->{___params}->{RootDir});
}

sub parse {
	my $self = shift;
	my $data = shift || {};
	___parse_data($self->{___template___},$data,$self->{___params}->{BlockTag});
}

sub ___read_includes {
	my $text = shift;
	my $cur_path = shift;
	my $root_path = shift;
	while($text =~ m/<!--Include\s+(.+?)-->/) {
		my $pre_inc = $PREMATCH; # text before include
		my $post_inc = $POSTMATCH; # text after include
		my $include_filename = $1; # got include filename
		$include_filename = $cur_path . $include_filename; # make full path to include file
		$include_filename =~ s![^/]+/\.\./!/!g; #move up if needed
		$include_filename =~ s!/\.\./!/!g;
		unless(($include_filename =~ /^$root_path/) && (-e $include_filename)) {
			$text = $pre_inc . 
				"File '$include_filename' can't be included" .
				" in this document because of wrong file path" .
				$post_inc;
		} else {
			my $in = '';
			local($/) = undef;
			open IN, "< $include_filename";
			$in = <IN>;
			close IN;
			my $new_cur_path = $include_filename;
			$new_cur_path =~ s![^/]*$!!;
			$text = $pre_inc . ___read_includes($in,$new_cur_path,$root_path) . $post_inc;
		}
	}
	return $text;
}

sub ___parse_template {
	my $text = shift;
	my $block_tag = shift;
	my $cur_path = shift;
	my $root_path = shift;
	my $tmp = {___text___=>'',___blocks___=>{}};
	while($text) {
		if($text =~ m/<!--($block_tag)\s+(.+?)-->(.*?)<!--\/\1\s+?\2-->/s) {
			my $block_name = $2;
			my $block_text = $3;
			$tmp->{___text___} .= $PREMATCH;
			$text = $POSTMATCH;
			$tmp->{___text___} .= "<!--${block_tag}_parsed $block_name-->";
			$tmp->{___blocks___}->{$block_name} = ___parse_template($block_text,$block_tag);
		} else {
			$tmp->{___text___} .= $text;
			$text = undef;
		}
	}
	return $tmp;
}

sub ___parse_data {
	my $template = shift || {};
	my $data = shift || {};
	my $block_tag = shift;
	my $text_level = $template->{___text___};
	my $text_result = '';
	my %data = ();
	my %blocks = ();
	my $key;
	foreach $key (keys %$data) {
		if(ref $data->{$key}) {
			$blocks{$key} = $data->{$key};
		} else {
			$data{$key} = $data->{$key};
		}
	}
	while($text_level) {
		if($text_level =~ m/<!--(${block_tag}_parsed) (.+?)-->/s) {
			my $block_name = $2;
			my $block;
			$text_result .= $PREMATCH;
			$text_level = $POSTMATCH;
			foreach $block (@{$blocks{$block_name}}) {
#				$text_result .= "<!--BlockParsed $block_name-->";
				$text_result .= ___parse_data($template->{___blocks___}->{$block_name},$block,$block_tag);
#				$text_result .= "<!--/BlockParsed $block_name-->";
			}
		} else {
			$text_result .= $text_level;
			$text_level = undef;
		}
	}

	# put local macro value or leave for global value changes
	$text_result =~ s/<%\s*(.+?)\s*%>/$data{$1} || "<% $1 %>"/ge;
	return $text_result;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

CGI::okTemplate - Perl extension for easy creating websites with using templates

=head1 SYNOPSIS

  use CGI::okTemplate;
  my $tmp = new CGI::okTemplate();
  $tmp->read_template('t/test.tpl');
  print $tmp->parse($data);

=head1 DESCRIPTION

This is an object oriented template module which parses template files
and puts data instead of macros.

Srtucture of the template file is:

Document: <Items>

Items: <Item> | <Item><Items>

Item: <Text> | <Block> | <Macro> | NOTHING

Text: <Symbols>

Symbols: <Symbol> | <Symbol><Symbols>

Symbol: <NameSymbol> | !<NameSymbol>

Block: <!--TemplateBlock <BlockName>--><Items><!--/TemplateBlock <BlockName>-->

BlockName: <NameSymbols>

NameSymbols: <NameSymbol>[<NameSymbols>]

NameSymbol: ['A'..'Z''a'..'z''0'..'9''_'<Space>]

Space: [\s\t]

Macro: <%<Spaces>?<MacroName><Spaces>?%>

Spaces: <Space> | <Space><Spaces>

MacroName: <NameSymbols>


You can put Blocks inside outer Blocks.

Stub documentation for CGI::okTemplate, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Oleg Kobyakovskiy, E<lt>ok &at; softaddicts &dot; comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Oleg Kobyakovskiy

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
