#!/usr/bin/env perl
use strict;
use warnings;

sub parse_markdown {
    my ($markdown, $filename) = @_;
    my @html;

    my $in_list = 0;
    my @para_lines;
    my @blockquote_lines;
    my %metadata;
    my $parsing_metadata = 1;

    my @lines = split /\n/, $markdown;

    for my $line (@lines) {
        # Metadata Parsing
        if ($parsing_metadata) {
            my $trimmed = $line;
            $trimmed =~ s/\s+$//;
            if ($trimmed =~ /^([a-z]+):\s*(.*)$/i) {
                $metadata{lc($1)} = $2;
                next;
            } elsif ($trimmed eq '') {
                $parsing_metadata = 0;
                _render_metadata(\@html, \%metadata) if %metadata;
                next;
            } else {
                $parsing_metadata = 0;
            }
        }

        # Headers
        if ($line =~ /^(#{1,6})\s+(.*)$/) {
            _close_active_blocks(\@html, \$in_list, \@para_lines, \@blockquote_lines);
            my $level = length($1);
            my $header_text = $2;
            $header_text =~ s/\s+$//;
            push @html, "<h$level>" . _process_inline($header_text) . "</h$level>";
        }
        
        # Blockquotes
        elsif ($line =~ /^>\s?(.*)$/) {
            _close_active_blocks(\@html, \$in_list, \@para_lines, []);
            push @blockquote_lines, $1;
        }
        
        # Unordered Lists (Hyphens or Asterisks)
        elsif ($line =~ /^[-*]\s+(.*)$/) {
            _close_active_blocks(\@html, \my $dummy, \@para_lines, \@blockquote_lines);
            if (!$in_list) {
                push @html, "<ul>";
                $in_list = 1;
            }
            my $item_text = $1;
            $item_text =~ s/\s+$//;
            push @html, "  <li>" . _process_inline($item_text) . "</li>";
        }
        
        # Blank lines (Structural dividers reset state)
        elsif ($line =~ /^\s*$/) {
            _close_active_blocks(\@html, \$in_list, \@para_lines, \@blockquote_lines);
        }

        # Horizontal rules
        elsif ($line =~ /^ {0,3}([-_*])(?:[ \t]*\1){2,}[ \t]*$/) {
            _close_active_blocks(\@html, \$in_list, \@para_lines, \@blockquote_lines);
            push @html, "<hr>";
        }

        else {
            _close_active_blocks(\@html, \$in_list, [], \@blockquote_lines);
            push @para_lines, $line;
        }
    }
    _close_active_blocks(\@html, \$in_list, \@para_lines, \@blockquote_lines);

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

sub _close_active_blocks {
    my ($html_ref, $in_list_ref, $para_lines_ref, $blockquote_lines_ref) = @_;
    
    if ($$in_list_ref) {
        push @$html_ref, "</ul>";
        $$in_list_ref = 0;
    }
    if (@$para_lines_ref) {
        my @para;
        for my $l (@$para_lines_ref) {
            my $has_hard_break = 0;
            if ($l =~ s/\\$//) {
                $has_hard_break = 1;
            } elsif ($l =~ s/ {2,}$//) {
                $has_hard_break = 1;
            }
            $l =~ s/\s+$//;
            my $processed = _process_inline($l);
            if ($has_hard_break) {
                $processed .= "<br>";
            }
            push @para, $processed;
        }
        push @$html_ref, "<p>" . join("\n", @para) . "</p>";
        @$para_lines_ref = ();
    }
    if (@$blockquote_lines_ref) {
        my @paragraphs;
        my @current_p;
        for my $l (@$blockquote_lines_ref) {
            my $trimmed_l = $l;
            $trimmed_l =~ s/\s+$//;
            if ($trimmed_l eq '') {
                if (@current_p) {
                    push @paragraphs, [@current_p];
                    @current_p = ();
                }
            } else {
                push @current_p, $l;
            }
        }
        if (@current_p) {
            push @paragraphs, [@current_p];
        }
        
        my @bq_html;
        for my $p_ref (@paragraphs) {
            my @para;
            for my $l (@$p_ref) {
                my $has_hard_break = 0;
                if ($l =~ s/\\$//) {
                    $has_hard_break = 1;
                } elsif ($l =~ s/ {2,}$//) {
                    $has_hard_break = 1;
                }
                $l =~ s/\s+$//;
                my $processed = _process_inline($l);
                if ($has_hard_break) {
                    $processed .= "<br>";
                }
                push @para, $processed;
            }
            push @bq_html, "<p>" . join("\n", @para) . "</p>";
        }
        push @$html_ref, "<blockquote>\n" . join("\n", @bq_html) . "\n</blockquote>";
        @$blockquote_lines_ref = ();
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

sub _process_inline {
    my ($text) = @_;

    # Hyperlinks: [text](url)
    $text =~ s/\[([^\[\]]+)\]\(([^()]+)\)/<a href="$2">$1<\/a>/g;

    # Bold: **bold** or __bold__
    $text =~ s/\*\*(?=\S)(.+?)(?<=\S)\*\*(?!\*)/<strong>$1<\/strong>/g;
    $text =~ s/\b__(?=\S)(.+?)(?<=\S)__\b/<strong>$1<\/strong>/g;

    # Italic: *italic* or _italic_
    $text =~ s/(?<!\*)\*(?!\*)(?=\S)(.+?)(?<=\S)(?<!\*)\*(?!\*)/<em>$1<\/em>/g;
    $text =~ s/\b_(?=\S)(.+?)(?<=\S)_\b/<em>$1<\/em>/g;

    return $text;
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

print parse_markdown($markdown_content, $filename);
