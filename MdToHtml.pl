#!/usr/bin/env perl
use strict;
use warnings;

sub parse_markdown {
    my ($markdown, $filename) = @_;
    my @html;

    my $in_list = 0;
    my %metadata;
    my $parsing_metadata = 1;

    my @lines = split /\n/, $markdown;

    for my $line (@lines) {
        $line =~ s/\s+$//;

        # Metadata Parsing
        if ($parsing_metadata) {
            if ($line =~ /^([a-z]+):\s*(.*)$/i) {
                $metadata{lc($1)} = $2;
                next;
            } elsif ($line eq '') {
                $parsing_metadata = 0;
                _render_metadata(\@html, \%metadata) if %metadata;
                next;
            }
        } else {
            $parsing_metadata = 0;
        }

        # Headers
        if ($line =~ /^(#{1,6})\s+(.*)$/) {
            _close_blocks(\@html, \$in_list);
            my $level = length($1);
            push @html, "<h$level>$2</h$level>";
        }
        
        # Blockquotes
        elsif ($line =~ /^>\s+(.*)$/) {
            _close_blocks(\@html, \$in_list);
            push @html, "<blockquote>$1</blockquote>";
        }
        
        # Unordered Lists (Hyphens or Asterisks)
        elsif ($line =~ /^[-*]\s+(.*)$/) {
            if (!$in_list) {
                push @html, "<ul>";
                $in_list = 1;
            }
            push @html, "  <li>$1</li>";
        }
        
        # Blank lines (Structural dividers reset state)
        elsif ($line eq '') {
            _close_blocks(\@html, \$in_list);
        }
        
        else {
            _close_blocks(\@html, \$in_list);
            push @html, "<p>$line</p>";
        }
    }
    _close_blocks(\@html, \$in_list);

    my $body_content = join("\n", @html);
    my $page_title = $metadata{title} || $filename =~ s/\.[^.]+$/.html/r;

    return <<"HTML";
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$page_title</title>
    <style>
        body {
            max-width: 80ch;
            margin: 0 auto;
            padding: 20px;
            font-family: sans-serif;
            text-align: center;
        }
        ul {
            list-style-position: inside;
            padding: 0;
        }
    </style>
</head>
<body>
$body_content
</body>
</html>
HTML
}

sub _close_blocks {
    my ($html_ref, $in_list_ref) = @_;
    
    if ($$in_list_ref) {
        push @$html_ref, "</ul>";
        $$in_list_ref = 0;
    }
}

sub _render_metadata {
    my ($html_ref, $meta) = @_;
    push @$html_ref, '<div class="metadata">';
    push @$html_ref, '  <div style="padding: 15px;">';
    push @$html_ref, '    <h2 style="margin: 0; padding: 10px 20px; border: 1px solid #333; background-color: #f5f5f5; color: #222; display: inline-block;">' . $meta->{title} . '</h2>' if $meta->{title};
    push @$html_ref, '    <div style="color: #666; font-size: 0.9em; font-style: italic; margin-top: 10px;">Published: ' . $meta->{date} . '</div>' if $meta->{date};
    push @$html_ref, '  </div>';
    push @$html_ref, '</div>';
}

if (@ARGV != 1) {
    die "Usage: $0 file.md\n";
}

my $filename = $ARGV[0];

open my $fh, '<', $filename
    or die "Fatal: Could not open file '$filename': $!\n";

my $markdown_content = do {
    local $/ = undef;
    <$fh>;
};

close $fh;

print parse_markdown($markdown_content);
