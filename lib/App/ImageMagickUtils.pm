package App::ImageMagickUtils;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Perinci::Exporter;

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Utilities related to ImageMagick',
};

our %arg0_files = (
    files => {
        'x.name.is_plural' => 1,
        'x.name.singular' => 'file',
        schema => ['array*' => of => 'filename*'],
        req => 1,
        pos => 0,
        slurpy => 1,
    },
);

sub _nearest {
    sprintf("%d", $_[0]/$_[1]) * $_[1];
}

$SPEC{downsize_image} = {
    v => 1.1,
    summary => 'Reduce image size, by default via compressing to JPEG quality 40 and downsizing to 1024p',
    description => <<'_',

This utility uses <prog:convert> utility to compress an image into JPEG with
default quality of 40 and downsized to 1024p (shortest side to 1024px).

Output filenames are:

    ORIGINAL_NAME.q40.jpg

or (if downsizing is done):

    ORIGINAL_NAME.1024p-q40.jgp

_
    args => {
        %arg0_files,
        q => {
            schema => ['int*', between=>[0,100]],
            default => 40,
        },
        downsize_to => {
            schema => ['str*', in=>['', '640', '800', '1024', '1536', '2048']],
            default => '1024',
            description => <<'_',

Downsizing will only be done if the input image's shortest side is indeed larger
then the target downsize.

To disable downsizing, set `--downsize-to` to '' (empty string), or specify on
`--dont-downsize` on the CLI.

_
            cmdline_aliases => {
                dont_downsize => {summary=>"Alias for --downsize-to ''", is_flag=>1, code=>sub {$_[0]{downsize_to} = ''}},
                no_downsize   => {summary=>"Alias for --downsize-to ''", is_flag=>1, code=>sub {$_[0]{downsize_to} = ''}},
            },
        },
    },
    features => {
        dry_run => 1,
    },
    examples => [
        {
            summary => 'The default setting is to downsize to 1024p',
            src => 'downsize-image *',
            src_plang => 'bash',
            test => 0,
            'x.doc.show_result' => 0,
        },
        {
            summary => 'Do not downsize, just recompress to JPEG quality 40',
            src => 'downsize-image --dont-downsize *',
            src_plang => 'bash',
            test => 0,
            'x.doc.show_result' => 0,
        },
    ],
};
sub downsize_image {
    require File::Which;
    require Image::Size;
    require IPC::System::Options;
    #require Filename::Image;

    my %args = @_;

    my $convert_path = File::Which::which("convert");
    my $downsize_to = $args{downsize_to};

    unless ($args{-dry_run}) {
        return [400, "Cannot find convert in path"] unless defined $convert_path;
        return [400, "convert path $convert_path is not executable"] unless -x $convert_path;
    }

    for my $file (@{$args{files}}) {
        log_info "Processing file %s ...", $file;

        unless (-f $file) {
            log_error "No such file %s, skipped", $file;
            next;
        }

        #my $res = Filename::Image::check_image_filename(filename => $file);
        my ($width, $height, $fmt) = @_;
        unless ($width) {
            log_error "Filename '%s' is not image (%s), skipped", $file, $fmt;
            next;
        }

        my $q = $args{q} // 40;
        my @convert_args = (
            $file,
        );

        my $downsized;
      DOWNSIZE: {
            last unless $downsize_to;
            my $ratio;
            my $shortest_side = $width > $height ? $height : $width;
            last unless $shortest_side > $downsize_to;
            $downsized++;
            push @convert_args, "-resize", "$downsize_to^>";
        } # DOWNSIZE

        push @convert_args, "-quality", $q;

        my $output_file = $file;
        my $ext = $downsized ? ".$downsize_to-q$q.jpg" : ".q$q.jpg";
        $output_file =~ s/(\.\w{3,4})?\z/($1 eq ".jpg" ? "" : $1) . $ext/e;

        push @convert_args, (
            $output_file,
        );

        if ($args{-dry_run}) {
            log_info "[DRY-RUN] Running $convert_path with args %s ...", \@convert_args;
            next;
        }

        IPC::System::Options::system(
            {log=>1},
            $convert_path, @convert_args,
        );
        if ($?) {
            my ($exit_code, $signal, $core_dump) = ($? < 0 ? $? : $? >> 8, $? & 127, $? & 128);
            log_error "convert for $file failed: exit_code=$exit_code, signal=$signal, core_dump=$core_dump";
        }
    }

    [200];
}

1;
# ABSTRACT:
