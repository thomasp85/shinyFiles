fileext <- list.files('inst/www/icons/Icons16x16/', pattern='file_extension_*')
fileext <- sub('file_extension_', '', fileext)
fileext <- sub('.png', '', fileext, fixed=T)

for(i in fileext) {
    write(paste0('.sF-file .sF-file-icon.sF-filetype-', i, ' {'), 'fileIcons.css', append=T)
    write(paste0('    content: url(icons/Icons16x16/file_extension_', i, '.png);'), 'fileIcons.css', append=T)
    write('}', 'fileIcons.css', append=T)
    write(paste0('.sF-fileList.sF-icons .sF-file .sF-file-icon.sF-filetype-', i, ' {'), 'fileIcons.css', append=T)
    write(paste0('    content: url(icons/Icons32x32/file_extension_', i, '.png);'), 'fileIcons.css', append=T)
    write('}\n', 'fileIcons.css', append=T)
}
other <- list(
    "page_white_actionscript.png"=c('as'),
    "page_white_c.png"=c('c'),
    "page_white_code.png"=c('r', 'R', 'lua', 'm', 'pl', 'py', 'sh', 'js', 'css', 'fs', 'fsx', 'el', 'lisp', 'cl', 'lsp', 'pas', 's', 'm', 'f', 'for', 'f90'),
#    "page_white_compress.png"=c(),
    "page_white_cplusplus.png"=c('C', 'cc', 'cpp', 'CPP', 'c++', 'cp', 'cxx'),
    "page_white_csharp.png"=c('cs'),
    "page_white_cup.png"=c('java', 'class', 'jar'),
    "page_white_database.png"=c("4db", "4dd", "4dindx", "4dindy", "4dr", "adt", "apr", "box", 
                                "chml", "daf", "dat", "db", "dbf", "eap", "egt", "ess", "fdb", 
                                "fp", "fp3", "fp5", "fp7", "frm", "gdb", "gtable", "kexi", "kexic", 
                                "myd", "myi", "ncf", "nsf", "ntf", "nv2", "odb", "ora", "pdb", 
                                "pdi", "pdx", "prc", "rec", "rel", "rin", "sdb", "sdf", "sql", 
                                "udl", "wadata", "waindx", "wajournal", "wamodel", "wdb", "wmdb", 
                                "4DB", "4DD", "4DIndy", "4DIndx", "4DR", "ADT", "APR", "BOX", 
                                "CHML", "DAF", "DAT", "DB", "DBF", "EGT", "ESS", "EAP", "FDB", 
                                "FP", "FP3", "FP5", "FP7", "FRM", "GDB", "GTABLE", "KEXI", "KEXIC", 
                                "MYD", "MYI", "NCF", "NSF", "NTF", "NV2", "ODB", "ORA", "PDB", 
                                "PDI", "PDX", "PRC", "SQL", "REC", "REL", "RIN", "SDB", "SDF", 
                                "UDL", "waData", "waIndx", "waModel", "waJournal", "WDB", "WMDB", 'Rdata', 'rdata', 'RDS'
    ),
    "page_white_excel.png"=c('xlm', 'xlt', 'xlsx', 'xlsm', 'xltx', 'xltm', 'xlsb', 'xla', 'xlam', 'xll', 'xlw'),
#    "page_white_flash.png"=c('swf', 'flv', 'fla'),
#    "page_white_gear.png"=c(),
    "page_white_h.png"=c('h'),
    "page_white_office.png"=c('ade', 'adp', 'adn', 'accdb', 'accdr', 'accdt', 'mdb', 'cdb', 'mda', 'mdn', 'mdt', 'mdw', 'mdf', 'mde', 'accde', 'mam', 'maq', 'mar', 'mat', 'maf', 'ldb', 'laccdb'),
    "page_white_php.png"=c('PHP', 'php', 'phtml', 'php4', 'php3', 'php5', 'phps'),
    "page_white_picture.png"=c('tiff', 'jif', 'jfif', 'jp2', 'jpx', 'j2k', 'j2c', 'fpx', 'pcd'),
    "page_white_powerpoint.png"=c('pot', 'pps', 'pptx', 'pptm', 'potx', 'potm', 'ppam', 'ppsx', 'ppsm', 'sldx', 'sldm'),
    "page_white_ruby.png"=c('rb', 'rbw'),
    "page_white_vector.png"=c('svg', 'drw'),
    "page_white_word.png"=c('dot', 'docx', 'docm', 'dotx', 'dotm'),
    "page_white_zip.png"=c('deb', 'pkg', 'rpm', 'tar', 'zipx'),
    "film.png"=c('amv', 'avi', 'moov', 'qt'),
    "music.png"=c('iff', 'mp3', 'mpa', 'ra', 'flac', 'act', 'aac', 'mmf')
    )

for(i in 1:length(other)) {
    filename <- names(other)[i]
    extensions <- other[[i]]
    extensions <- extensions[!extensions %in% fileext]
    
    for(j in 1:length(extensions)) {
        write(paste0('.sF-file .sF-file-icon.sF-filetype-', extensions[j], ifelse(j == length(extensions), ' {', ',')), 'fileIcons.css', append=T)
    }
    write(paste0('    content: url(icons/Icons16x16/', filename, ');'), 'fileIcons.css', append=T)
    write('}', 'fileIcons.css', append=T)
    for(j in 1:length(extensions)) {
        write(paste0('.sF-fileList.sF-icons .sF-file .sF-file-icon.sF-filetype-', extensions[j], ifelse(j == length(extensions), ' {', ',')), 'fileIcons.css', append=T)
    }
    write(paste0('    content: url(icons/Icons32x32/', filename, ');'), 'fileIcons.css', append=T)
    write('}\n', 'fileIcons.css', append=T)
    
}