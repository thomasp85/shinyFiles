var shinyFiles = (function() {
    
  // General functionality
    
  var elementSelector = function(event, element, single, forceSelect) {
    var parent = $(element).parent();
    var lastSelectedElement = parent.data('lastElement');
    
    function toggleSelection(element) {
      $(element).toggleClass('selected');
      parent.data('lastElement', element);
    }
    
    function selectElementsBetweenIndexes(indexes) {
      var els = parent.children();
        indexes.sort(function(a, b) {
          return a - b;
        });
    
        for (var i = indexes[0]; i <= indexes[1]; i++) {
          $(els[i]).addClass('selected');
        }
    }
    
    function clearAll() {
      parent.children().removeClass('selected');
    }
  
    if (event.button === 0) {
      if ((!event.metaKey && !event.ctrlKey && !event.shiftKey) || single) {
        var selected = $(element).hasClass('selected');
        var nSelected = parent.children('.selected').length;
          clearAll();
          if ((!selected || nSelected != 1) || forceSelect) {
            toggleSelection(element);               
          }
      } else if ((event.metaKey || event.ctrlKey) && !single) {
        toggleSelection(element);
      } else if (event.shiftKey && !single) {
        selectElementsBetweenIndexes([$(lastSelectedElement).index(), $(element).index()]);
      }
    }
  };
  
  var compareArrays = function (arrayA, arrayB) {
    /*
    Modified from Tomáš Zatos answer at http://stackoverflow.com/questions/7837456/comparing-two-arrays-in-javcript
    */
      
    // if the other array is a falsy value, return
    if (!arrayA || !arrayB)
     return false;
  
    // compare lengths - can save a lot of time
    if (arrayA.length != arrayB.length)
      return false;

    for (var i = 0, l=arrayA.length; i < l; i++) {
      // Check if we have nested arrays
      if (arrayA[i] instanceof Array && arrayB[i] instanceof Array) {
        // recurse into the nested arrays
        if (!compareArrays(arrayA[i], arrayB[i]))
          return false;
      } else if (arrayA[i] != arrayB[i]) {
        // Warning - two different object instances will never be equal: {x:20} != {x:20}
        return false;
      }
    }
    return true;
  };
  
  vaobjSize = function(obj) {
    /*
    From http://stackoverflow.com/questions/5223/length-of-javascript-object-ie-associative-array answer by Jameglan
    */
    var size = 0, key;
    for (key in obj) {
      if (obj.hasOwnProperty(key)) size++;
    }
    return size;
  };
  
  $.fn.sortChildren = function(map, reverse) {
    /*
    Adapted from https://gist.github.com/rodneyrehm/2818576
    */
    var sortChildren = {
      // default comparison function using String.localeCompare if possible
      compare: function(a, b) {
        if ($.isArray(a.value)) {
          return sortChildren.compareList(a.value, b.value);
        }
        return sortChildren.compareValues(a.value, b.value);
      },
      
      compareValues: function(a, b) {
        if (typeof a === "string" && "".localeCompare) {
          return a.localeCompare(b);
        }
     
        return a === b ? 0 : a > b ? 1 : -1;
      },
     
      // default comparison function for DESC
      reverse: function(a, b) {
        return -1 * sortChildren.compare(a, b);
      },
     
      // default mapping function returning the elements' lower-cased innerTEXT
      map: function(elem) {
        return $(elem).text().toLowerCase();
      },
     
      // default comparison function for lists (e.g. table columns)
      compareList: function(a, b) {
        var i = 1,
          length = a.length,
          res = sortChildren.compareValues(a[0], b[0]);
    
        while (res === 0 && i < length) {
          res = sortChildren.compareValues(a[i], b[i]);
          i++;
        }
     
        return res;
      }
    };
    
    return this.each(function() {
      var $this = $(this),
        $children = $this.children(),
        _map = [],
        length = $children.length,
        i;
    
      for (i = 0; i < length ; i++) {
        _map.push({
          index: i, 
          value: (map || sortChildren.map)($children[i])
        });
      }
      
      _map.sort(reverse ? sortChildren.reverse : sortChildren.compare);
      
      for (i = 0; i < length ; i++) {
        this.appendChild($children[_map[i].index]);
      }
    });
  };
  
  var parseFiles = function(data) {
    var parsedFiles = {};
    data.files.filename.forEach(function(d, i) {
      try{
        var mTime = data.files.mtime[i].split('-');
        var cTime = data.files.ctime[i].split('-');
        var aTime = data.files.atime[i].split('-');
        // month index starts as zero
        parsedFiles[d] = {
          name: d,
          extension: data.files.extension[i],
          isDir: data.files.isdir[i],
          size: data.files.size[i],
          mTime: new Date(mTime[0], mTime[1]-1, mTime[2], mTime[3], mTime[4]),
          cTime: new Date(cTime[0], cTime[1]-1, cTime[2], cTime[3], cTime[4]),
          aTime: new Date(aTime[0], aTime[1]-1, aTime[2], aTime[3], aTime[4])
        };
      } catch(err) {
        //This can happen if there is a broken link, for example
      }
    });
    
    return {
      files: parsedFiles,
      location: data.breadcrumps,
      writable: data.writable,
      rootNames: data.roots,
      selectedRoot: data.root
    };
  };
    
  var formatDate = function(date) {
    var monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    var dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    
    if (typeof Intl == 'undefined') {
      return dayNames[date.getDay()]+' '+monthNames[date.getMonth()]+' '+date.getDate()+' '+date.getFullYear()+' '+date.getHours()+':'+("0" + date.getMinutes()).substr(-2);
    } else {
      return date.toLocaleString([], {weekday:'long', year:'numeric', month:'short', day:'numeric', hour:'2-digit', minute:'2-digit'});
    }
  };
  
  var formatSize = function(bytes, si) {
    /*
    This function is taken from http://stackoverflow.com/questions/10420352/converting-file-size-in-bytes-to-humeadable - Mark's answer    
    */
    var thresh = si ? 1000 : 1024;
    if(bytes < thresh) return bytes + ' B';
    var units = si ? ['kB','MB','GB','TB','PB','EB','ZB','YB'] : ['KiB','MiB','GiB','TiB','PiB','EiB','ZiB','YiB'];
    var u = -1;
    do {
      bytes /= thresh;
      ++u;
    } while(bytes >= thresh);
    return bytes.toFixed(1)+' '+units[u];
  };
  
  var initializeButton = function(button) {
    var type = $(button).hasClass('shinyDirectories') ? 'directory' : 'file';
    var sort = $(button).data('sort') || 'Name';
    var sortDir = $(button).data('sortDir') || 'ascending';
    
    if(type == 'file') {
      var back = $(button).data('back') || [];
      var forward = $(button).data('forward') || [];
      var view = $(button).data('view') || '';
      $(button).data('back', back)
        .data('forward', forward)
        .data('view', view);
      if($(button).hasClass('shinySave')) {
        var filetypes = $(button).data('filetype');
        filetypes.forEach(function(d) {
          if(d === null) return;
          d.ext = d.ext.map(function(ext) {
            return ext[0] == '.' ? ext : '.'+ext;
          });
        });
      }
    }
    $(button).data('sort', sort)
      .data('sortDir', sortDir);
  };
  
  var setDisabledButtons = function(button, modal) {
    var type = $(button).hasClass('shinyDirectories') ? 'directory' : 'file';
    
    if(type == 'file') {
      var back = $(button).data('back').length === 0;
      var forward = $(button).data('forward').length === 0;
      var up = $(modal).find('.sF-breadcrumps>option').length <= 1;
      
      $(modal).find('#sF-btn-back').prop('disabled', back);
      $(modal).find('#sF-btn-forward').prop('disabled', forward);
      $(modal).find('#sF-btn-up').prop('disabled', up);
    }
  };
  
  var filesSelected = function(modal) {
    var type = $($(modal).data('button')).hasClass('shinyDirectories') ? 'directory' : 'file';
    
    if(type == 'file') {
      return modal.find('.sF-fileList').children().filter('.sF-file.selected').length > 0;
    } else {
      return modal.find('.sF-dirList').find('.selected').length > 0;
    }
  };
  
  var toggleSelectButton = function(modal) {
    modal.find('#sF-selectButton').prop('disabled', !filesSelected(modal));
  };
  
  var sortFiles = function(modal, attribute, direction) {
    var type = $($(modal).data('button')).hasClass('shinyDirectories') ? 'directory' : 'file';
    var fileList;
    if (type == 'file') {
      fileList = $(modal).find('.sF-fileList');
    } else {
      fileList = $(modal).find('.sF-dirContent');
    }
  
  
    fileList.sortChildren(function(elem) {
      return $(elem).data('sF-file') ? $(elem).data('sF-file').name : '';
    }, direction == 'descending');
    
    if (attribute == 'Name') return;
    
    switch (attribute) {
      case 'Type':
        fileList.sortChildren(function(elem) {
          return $(elem).data('sF-file') ? $(elem).data('sF-file').isDir ? '000' : $(elem).data('sF-file').extension || '001' : '';
        }, direction == 'descending');
        break;
      case 'Size':
        fileList.sortChildren(function(elem) {
          return $(elem).data('sF-file') ? $(elem).data('sF-file').isDir ? -1 : $(elem).data('sF-file').size : 0;
        }, direction == 'descending');
        break;
      case 'Created':
        fileList.sortChildren(function(elem) {
          return $(elem).data('sF-file') ? $(elem).data('sF-file').cTime : new Date();
        }, direction == 'descending');
        break;
      case 'Modified':
        fileList.sortChildren(function(elem) {
          return $(elem).data('sF-file') ? $(elem).data('sF-file').mTime : new Date();
        }, direction == 'descending');
        break;
    }
  }
        
  var removeFileChooser = function(button, modal, data) {

    var modal = $(modal).removeClass('in');
    var backdrop = $(modal).data('backdrop').removeClass('in');
    
    setTimeout(function() {
      modal.remove();
      backdrop.remove();
      if(data !== undefined) {
        Shiny.onInputChange($(button).attr('id'), data);
      }
    }, 300);
    $(button).prop('disabled', false)
      .data('modal', null);
  };
  
  var dismissFileChooser = function(button, modal) {
    removeFileChooser(button, modal);
    $(button).trigger('cancel');
  };
    
  var selectFiles = function(button, modal) {
    var type = $(button).hasClass('shinyDirectories') ? 'directory' : 'file';
    
    if(type == 'file') {
      var files = getSelectedFiles(modal);
      $(button).data('files', files)
        .trigger('selection', [files])
        .trigger('fileselect', [files]);
      var data = {
        files: $.extend({}, files.files.toArray().map(function(d) {
          return d;
        })),
        root: files.root
      };
    } else {
      var path = getPath($(modal).find('.sF-dirList .selected'));
      $(button).data('directory', path)
        .trigger('selection', path);
      var data = {
        path: path,
        root: $(modal).data('currentData').selectedRoot
      };
    }
    
    removeFileChooser(button, modal, data);
  };
    
    var setPermission = function(modal, writable) {
      var currentState = $(modal).find('.sF-permission').length == 0;
      var footer = $(modal).find('.modal-footer');
      var overwrite = $($(modal).data('button')).hasClass('shinySave') ? true : filesSelected(modal);
      
      $(modal).find('#sF-btn-newDir').prop('disabled', !(overwrite && writable));
      
      if(writable || !overwrite) {
        footer.find('.sF-permission').remove();
      } else if(currentState != writable) {
        footer.prepend(
          $('<div>').addClass('sF-permission text-warning').append(
            $('<span>').addClass('glyphicon glyphicon-warning-sign')
          ).append(
            $('<span>').text('No write permission for folder')
          )
        )
      }
    }
  // General functionality ends
    
    
  // File chooser
  var createFileChooser = function(button, title) {
    // Preparations
    
    $(button).prop('disabled', true);
    
    initializeButton(button);
    
    // Creating modal
    var modal = $('<div>', {id: $(button).attr('id')+'-modal'}).addClass('sF-modalContainer modal fade').css('display', 'block').append(
      $('<div>').addClass('sF-modal modal-dialog').append(
        $('<div>').addClass('modal-content').append(
          $('<div>').addClass('modal-header').append(
            $('<button>', {html: '&times;', type: 'button'}).addClass('close')
          ).append(
            $('<h4>', {text: title}).addClass('sF-title modal-title')
          )
        ).append(
          $('<div>').addClass('modal-body').append(
            $('<div>').addClass('sF-navigation btn-toolbar').append(
              $('<div>').addClass('btn-group btn-group-sm sF-navigate').append(
                $('<button>', {id: 'sF-btn-back'}).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-chevron-left')
                )
              ).append(
                $('<button>', {id: 'sF-btn-up'}).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-arrow-up')
                )
              ).append(
                $('<button>', {id: 'sF-btn-forward'}).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-chevron-right')
                )
              )
            ).append(
              $('<div>').addClass('btn-group btn-group-sm sF-view').append(
                $('<button>', {id: 'sF-btn-icon'}).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-th')
                )
              ).append(
                $('<button>', {id: 'sF-btn-list'}).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-th-list')
                )
              ).append(
                $('<button>', {id: 'sF-btn-detail'}).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-align-justify')
                )
              )
            ).append(
              $('<div>').addClass('sF-sort dropdown btn-group btn-group-sm').append(
                $('<button>', {id: 'sF-btn-sort'}).addClass('btn btn-default dropdown-toggle').append(
                  $('<span>').addClass('glyphicon glyphicon-sort-by-attributes')
                )
              ).append(
                $('<ul>').addClass('dropdown-menu').append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', {href: '#', text: 'Name'}).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Name' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', {href: '#', text: 'Type'}).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Type' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', {href: '#', text: 'Size'}).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Size' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', {href: '#', text: 'Created'}).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Created' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', {href: '#', text: 'Modified'}).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Modified' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('divider')
                ).append(
                  $('<li>').addClass('sortDir').append(
                    $('<a>', {href: '#', text: 'Sort direction'}).addClass($(button).data('sortDir')).prepend($('<span>').addClass('glyphicon glyphicon-arrow-down')).prepend($('<span>').addClass('glyphicon glyphicon-arrow-up'))
                  )
                )
              )
            ).append(
              $('<select>').addClass('sF-breadcrumps form-control input-sm')
            )
          ).append(
            $('<div>').addClass('sF-fileWindow').append(
              $('<div>').addClass('sF-fileList')
            )
          )
        ).append(
          $('<div>').addClass('sF-responseButtons modal-footer').append(
            $('<button>', {text: 'Cancel', type: 'button', id: 'sF-cancelButton'}).addClass('btn btn-default')
          ).append(
            $('<button>', {text: 'Select', type: 'button', id: 'sF-selectButton'}).addClass('btn btn-primary')
          )
        )
      )
    ).appendTo($('body'));
        
    var backdrop = $('<div>')
      .addClass('sF-modalBackdrop modal-backdrop fade')
      .appendTo($('body'));
    
    // HANDLER BINDING
      
    // Dismissers and selecters
    modal.find('.modal-header button.close').on('click', function() {
      dismissFileChooser(button, modal)
    })

    modal.find('.sF-responseButtons #sF-cancelButton').on('click', function() {
      dismissFileChooser(button, modal);
    })
    modal.find('.sF-responseButtons #sF-selectButton').on('click', function() {
      selectFiles(button, modal);
    })
        
    // Button navigation
    modal.find('.sF-navigate #sF-btn-back').on('click', function() {
      moveBack(button, modal);
    })
    modal.find('.sF-navigate #sF-btn-up').on('click', function() {
      moveUp(button, modal);
    })
    modal.find('.sF-navigate #sF-btn-forward').on('click', function() {
      moveForward(button, modal);
    })
        
    // View changing
    modal.find('.sF-view').on('click', 'button', function() {
      changeView(button, modal, $(this));
    })
        
    // Sort content
    modal.find('.sF-sort').on('click', function() {
      $(this).toggleClass('open')
        .find('button').toggleClass('active');
      return false;
    })
    modal.find('.sF-sort ul')
      .on('click', 'li.sortAttr', function() {
        $(this).siblings('.sortAttr').removeClass('selected');
        $(this).toggleClass('selected', true);
        
        $(modal).trigger('fileSort', [$(this).find('a').text(), $(this).siblings('.sortDir').find('a').attr('class')])
      })
      .on('click', 'li.sortDir', function() {
        $(this).find('a').toggleClass('ascending').toggleClass('descending')
        
        $(modal).trigger('fileSort', [$(this).parent().find('.selected a').text(), $(this).find('a').attr('class')])
      })
        
    // Breadcrump and volume navigation
    modal.find('.sF-breadcrumps').on('change', function() {
      moveToDir(button, modal, this);
    })
        
    // File window
    modal.find('.sF-fileWindow')
      .on('click', function() {
        modal.find('.sF-fileList .selected').toggleClass('selected');
        toggleSelectButton(modal);
      })
      .on('dblclick', '.sF-file', function(event) {
        var single = $(button).data('selecttype') == 'single';
        elementSelector(event, this, single, false);
        selectFiles(button, modal);
      })
      .on('click', '.sF-file, .sF-directory', function(event) {
        var single = $(button).data('selecttype') == 'single';
        elementSelector(event, this, single, false);
        toggleSelectButton(modal);
        return false;
      })

    // Custom events
    modal
      .on('change', function() {
        setDisabledButtons(button, modal);
      })
      .on('fileSort', function(elem, attribute, direction) {
        $(button).data('sort', attribute).data('sortDir', direction);
        sortFiles(modal, attribute, direction);
      });
        
        
    // Binding data
    modal.data('backdrop', backdrop);
    modal.data('button', button);
    $(button).data('modal', modal);
    
    // Setting states
    var view = $(button).data('view') || 'sF-btn-icon';
    changeView(button, modal, modal.find('#'+view));
    
    // Ready to enter
    setTimeout(function() {
      modal.addClass('in');
      backdrop.addClass('in');
    }, 1);
    
    populateFileChooser(button, $(button).data('dataCache'));
  };

  var populateFileChooser = function(element, data) {
    var modal = $(element).data('modal');
      
    $(element).data('dataCache', data);
      
    if(!modal) return;
        
    var currentData = modal.data('currentData');
    
    var single = $(element).data('selecttype') == 'single';
    
    var newLocation = currentData ? !(compareArrays(currentData.location, data.location) && currentData.selectedRoot == data.selectedRoot) : true;
    var newVolumes = currentData ? !compareArrays(currentData.rootNames, data.rootNames) : true;
    var newFiles = {};
    if (currentData) {
      for (i in data.files) {
        if (!currentData.files[i]) newFiles[i] = data.files[i];
      }
    };
    var oldFiles = {};
    if (currentData) {
      for (i in currentData.files) {
        if (!data.files[i]) oldFiles[i] = currentData.files[i];
      }
    };
    
    if (newLocation || newVolumes) {
      if (!data) return;
      modal.find('.sF-breadcrumps').find('option, optgroup').remove();
      data.location.forEach(function(d, i) {
        modal.find('.sF-breadcrumps').prepend(
          $('<option>', {html: '&#128193; ' + (d || data.selectedRoot), value: d}).data('location', data.location.slice(0, i+1))
        );
      });
      modal.find('.sF-breadcrumps').prop('selectedIndex', 0).data('selectedRoot', data.selectedRoot);
      
      var rootList = $('<optgroup>', {label: 'Volumes'}).appendTo(modal.find('.sF-breadcrumps'));
      data.rootNames.forEach(function(d) {
        rootList.append(
          $('<option>', {html: (d == data.selectedRoot ? '&#9679; ': '&#9675; ') + d, value: d})
        )
      })
    };
    
    if (newLocation) {
      modal.find('.sF-fileList').children().remove();
      
      modal.find('.sF-fileList').append(
        $('<div>').addClass('sF-file-header').append(
          $('<div>').append(
            $('<div>').addClass('sF-file-icon')
          ).append(
            $('<div>', {text: 'name'}).addClass('sF-file-name')
          ).append(
            $('<div>', {text: 'size'}).addClass('sF-file-size')
          ).append(
            $('<div>', {text: 'modified'}).addClass('sF-file-mTime')
          ).append(
            $('<div>', {text: 'created'}).addClass('sF-file-cTime')
          ).append(
            $('<div>', {text: 'accessed'}).addClass('sF-file-aTime')
          )
        )
      );
      
      for (i in data.files) {
        var d = data.files[i];
        
        modal.find('.sF-fileList').append(
          $('<div>').toggleClass('sF-file', !d.isDir).toggleClass('sF-directory', d.isDir).append(
            $('<div>').addClass('sF-file-icon').addClass('sF-filetype-'+d.extension)
          ).append(
            $('<div>').addClass('sF-file-name').append(
              $('<div>',  {text: d.name})
            )
          ).append(
            $('<div>', {text: d.isDir ? '' : formatSize(d.size, true)}).addClass('sF-file-size')
          ).append(
            $('<div>', {text: formatDate(d.mTime)}).addClass('sF-file-mTime')
          ).append(
            $('<div>', {text: formatDate(d.cTime)}).addClass('sF-file-cTime')
          ).append(
            $('<div>', {text: formatDate(d.aTime)}).addClass('sF-file-aTime')
          ).data('sF-file', d)
        );
      };
      modal.find('.sF-directory').on('dblclick', function() {
        $(this).toggleClass('selected', true);
        openDir($(element), modal, this);
      });
    } else {

      if (Object.keys(oldFiles).length === 0) {
        modal.find('.sF-fileList').children().filter(function() {
          return oldFiles[$(this).find('.sF-file-name div').text()]
        }).remove();
      };
      if (Object.keys(newFiles).length === 0) {
        for (i in newFiles) {
          var d = newFiles[i];
          
          modal.find('.sF-fileList').append(
            $('<div>').toggleClass('sF-file', !d.isDir).toggleClass('sF-directory', d.isDir).append(
              $('<div>').addClass('sF-file-icon').addClass('sF-filetype-'+d.extension)
            ).append(
              $('<div>').addClass('sF-file-name').append(
                $('<div>',  {text: d.name})
              )
            ).append(
              $('<div>', {text: d.isDir ? '' : formatSize(d.size, true)}).addClass('sF-file-size')
            ).append(
              $('<div>', {text: formatDate(d.mTime)}).addClass('sF-file-mTime')
            ).append(
              $('<div>', {text: formatDate(d.cTime)}).addClass('sF-file-cTime')
            ).append(
              $('<div>', {text: formatDate(d.aTime)}).addClass('sF-file-aTime')
            ).data('sF-file', d)
          );
        };
      };
    };
    
    if($(element).hasClass('shinySave')) {
      setPermission(modal, data.writable);
    }
    toggleSelectButton(modal);
    
    modal.data('currentData', data);
    $(modal).trigger('change');
  };
  
  var getSelectedFiles = function(modal) {
    var directory = getCurrentDirectory(modal);
    
    return {
      files: modal.find('.sF-fileList').find('.selected .sF-file-name div').map(function() {
        var dirCopy = directory.path.slice();
        dirCopy.push($(this).text());
        return [dirCopy];
      }),
      root: directory.root
    };
  };
  
  var getCurrentDirectory = function(modal) {
    return {
      path: modal.find('.sF-breadcrumps>option').map(function() {
        return $(this).val();
      }).toArray().reverse(),
      root: modal.find('.sF-breadcrumps').data('selectedRoot')
    };
  };
  
  var changeView = function(button, modal, view) {
    modal.find('.sF-view button').toggleClass('active', false);
    view.toggleClass('active', true);
    
    var detail = false;
    var icons = false;
    var list = false;
    
    switch (view.attr('id')) {
      case 'sF-btn-icon':
        icons = true;
        break;
      case 'sF-btn-list' :
        list = true;
        break;
      case 'sF-btn-detail' :
        detail = true;
        break;
    }
    
    modal.find('.sF-fileList').toggleClass('sF-detail', detail)
      .toggleClass('sF-icons', icons)
      .toggleClass('sF-list', list);
    modal.find('.sF-fileWindow')
      .scrollTop(0)
      .scrollLeft(0)
      .toggleClass('sF-wide', list);
    
    $(button).data('view', view.attr('id'));
  }
  
  var changeDirectory = function(button, modal, directory) {
    if (directory.path instanceof jQuery) directory.path = directory.path.toArray();
    
    Shiny.onInputChange($(button).attr('id')+'-modal', directory);
  };
  
  var moveBack = function(button, modal) {
    $('.sF-btn-back').prop('disabled', true);
    
    var newDir = $(button).data('back').pop();
    var currentDir = getCurrentDirectory(modal);
    
    changeDirectory(button, modal, newDir);
    if (!$(button).data('forward')) {
      $(button).data('forward', []);
    } 
    $(button).data('forward').push(currentDir);
  };
  
  var moveForward = function(button, modal) {
    $('.sF-btn-forward').prop('disabled', true);
    
    var newDir = $(button).data('forward').pop();
    var currentDir = getCurrentDirectory(modal);
    
    changeDirectory(button, modal, newDir);
    if (!$(button).data('back')) {
      $(button).data('back', []);
    } 
    $(button).data('back').push(currentDir);
  };
  
  var moveUp = function(button, modal) {
    $('.sF-btn-up').prop('disabled', true);
    
    var currentDir = getCurrentDirectory(modal);
    var newDir = {
      path: currentDir.path.slice(0, -1),
      root: currentDir.root
    };
    
    changeDirectory(button, modal, newDir);
    if (!$(button).data('back')) {
      $(button).data('back', []);
    } 
    $(button).data('back').push(currentDir);
    $(button).data('forward', []);
  };
  
  var moveToDir = function(button, modal, select) {
    var currentDir = getCurrentDirectory(modal);
    var newDir = {}
    var selection = $(select).find(':selected');
    
    if (selection.parent().is('optgroup')) {
      newDir.path = '';
      newDir.root = selection.val();
    } else {
      newDir.path = selection.data('location');
      newDir.root = $(select).data('selectedRoot')
    }
    
    changeDirectory(button, modal, newDir);
    if (!$(button).data('back')) {
      $(button).data('back', []);
    } 
    $(button).data('back').push(currentDir);
    $(button).data('forward', []);
  };
  
  var openDir = function(button, modal, dir) {
    var currentDir = getCurrentDirectory(modal);
    var newDir = {
      path: currentDir.path.slice(),
      root: currentDir.root
    }
    newDir.path.push($(dir).find('.sF-file-name').text());
    
    changeDirectory(button, modal, newDir);

    if (!$(button).data('back')) {
      $(button).data('back', []);
    } 
    $(button).data('back').push(currentDir);
    $(button).data('forward', []);
  }
  // File chooser ends
    
  // File saver
  var createFileSaver = function(button, title) {
  // Preparations
  
  $(button).prop('disabled', true);
  
  initializeButton(button);
  
  // Creating modal
  var modal = $('<div>', {id: $(button).attr('id')+'-modal'}).addClass('sF-modalContainer modal fade').css('display', 'block').append(
      $('<div>').addClass('sF-modal modal-dialog').append(
        $('<div>').addClass('modal-content').append(
          $('<div>').addClass('modal-header').append(
            $('<button>', {html: '&times;', type: 'button'}).addClass('close')
          ).append(
            $('<h4>', {text: title}).addClass('sF-title modal-title')
          )
        ).append(
          $('<div>').addClass('modal-body').append( 
            $('<div>').addClass('sF-navigation btn-toolbar').append(
              $('<div>').addClass('btn-group btn-group-sm sF-navigate').append(
                $('<button>', {id: 'sF-btn-back'}).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-chevron-left')
                )
              ).append(
                $('<button>', {id: 'sF-btn-up'}).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-arrow-up')
                )
              ).append(
                $('<button>', {id: 'sF-btn-forward'}).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-chevron-right')
                )
              )
            ).append(
              $('<div>').addClass('btn-group btn-group-sm sF-view').append(
                $('<button>', {id: 'sF-btn-icon'}).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-th')
                )
              ).append(
                $('<button>', {id: 'sF-btn-list'}).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-th-list')
                )
              ).append(
                $('<button>', {id: 'sF-btn-detail'}).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-align-justify')
                )
              )
            ).append(
              $('<div>').addClass('sF-sort dropdown btn-group btn-group-sm').append(
                $('<button>', {id: 'sF-btn-sort'}).addClass('btn btn-default dropdown-toggle').append(
                  $('<span>').addClass('glyphicon glyphicon-sort-by-attributes')
                )
              ).append(
                $('<ul>').addClass('dropdown-menu').append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', {href: '#', text: 'Name'}).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Name' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', {href: '#', text: 'Type'}).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Type' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', {href: '#', text: 'Size'}).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Size' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', {href: '#', text: 'Created'}).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Created' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', {href: '#', text: 'Modified'}).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Modified' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('divider')
                ).append(
                  $('<li>').addClass('sortDir').append(
                    $('<a>', {href: '#', text: 'Sort direction'}).addClass($(button).data('sortDir')).prepend($('<span>').addClass('glyphicon glyphicon-arrow-down')).prepend($('<span>').addClass('glyphicon glyphicon-arrow-up'))
                  )
                )
              )
            ).append(
              $('<select>').addClass('sF-breadcrumps form-control input-sm')
            )
          ).append(
            $('<div>').addClass('sF-fileWindow').append(
              $('<div>').addClass('sF-fileList')
            )
          ).append(
            $('<div>').addClass('input-group input-group-sm sF-filenaming').append(
              $('<div>').addClass('sF-newDir input-group-btn').append(
                $('<button>', {id: 'sF-btn-newDir', text: ' Create new folder'}).addClass('btn btn-default dropdown-toggle').prepend(
                  $('<span>').addClass('glyphicon glyphicon-folder-close')
                )
              ).append(
                $('<ul>').addClass('dropdown-menu').append(
                  $('<li>').append(
                    $('<div>').addClass('input-group input-group-sm').append(
                      $('<input>', {type: 'text', placeholder: 'Folder name', spellcheck: 'false'}).addClass('form-control')
                    ).append(
                      $('<span>').addClass('input-group-btn').append(
                        $('<button>', {type: 'button'}).addClass('btn btn-default').prop('disabled', true).append(
                          $('<span>').addClass('glyphicon glyphicon-plus-sign')    
                        )
                      )
                    )
                  )
                )
              )
            ).append(
              $('<input>', {type: 'text', value: $(button).attr('data-filename'), placeholder: 'filename', spellcheck: 'false'}).addClass('form-control sF-filename')
            )
          )
        ).append(
          $('<div>').addClass('sF-responseButtons modal-footer').append(
            $('<button>', {text: 'Cancel', type: 'button', id: 'sF-cancelButton'}).addClass('btn btn-default')
          ).append(
            $('<button>', {text: 'Save', type: 'button', id: 'sF-selectButton'}).addClass('btn btn-primary')
          )
        )
      )
    ).appendTo($('body'));
        
    addFiletypeChoice(button, modal);
        
    var backdrop = $('<div>')
      .addClass('sF-modalBackdrop modal-backdrop fade')
      .appendTo($('body'));
    
    // HANDLER BINDING
        
    // Dismissers and selecters
    modal.find('.modal-header button.close').on('click', function() {
      dismissFileChooser(button, modal)
    })
    modal.find('.sF-responseButtons #sF-cancelButton').on('click', function() {
      dismissFileChooser(button, modal);
    })
    modal.find('.sF-responseButtons #sF-selectButton').on('click', function() {
      saveFile(modal, button)
    })
        
    // Button navigation
    modal.find('.sF-navigate #sF-btn-back').on('click', function() {
      moveBack(button, modal);
    })
    modal.find('.sF-navigate #sF-btn-up').on('click', function() {
      moveUp(button, modal);
    })
    modal.find('.sF-navigate #sF-btn-forward').on('click', function() {
      moveForward(button, modal);
    })
        
    // View changing
    modal.find('.sF-view').on('click', 'button', function() {
      changeView(button, modal, $(this));
    })
        
    // Sort content
    modal.find('.sF-sort').on('click', function() {
      $(this).toggleClass('open')
        .find('button').toggleClass('active');
      return false;
    })
    modal.find('.sF-sort ul')
      .on('click', 'li.sortAttr', function() {
        $(this).siblings('.sortAttr').removeClass('selected');
        $(this).toggleClass('selected', true);
        
        $(modal).trigger('fileSort', [$(this).find('a').text(), $(this).siblings('.sortDir').find('a').attr('class')])
      })
      .on('click', 'li.sortDir', function() {
        $(this).find('a').toggleClass('ascending').toggleClass('descending')
        
        $(modal).trigger('fileSort', [$(this).parent().find('.selected a').text(), $(this).find('a').attr('class')])
      })
        
    // Breadcrump and volume navigation
    modal.find('.sF-breadcrumps').on('change', function() {
      moveToDir(button, modal, this);
    })
        
    // File window
    modal.find('.sF-fileWindow')
      .on('click', function() {
        modal.find('.sF-fileList .selected').toggleClass('selected');
        toggleSelectButton(modal);
      })
      .on('click', '.sF-file, .sF-directory', function(event) {
        elementSelector(event, this, true, false);
        if(!$(this).hasClass('sF-directory')) {
            var name = $(this).find('.sF-file-name>div').text();
            setFilename(modal, name);
        }
        return false;
      })
        
    // Folder creation
    modal.find('.sF-newDir').on('click', function() {
      var disabled = $(this).find('button').prop('disabled')
      if (!disabled) {
        $(this).toggleClass('open')
          .find('button.sF-btn-newDir').toggleClass('active');
        if ($(this).hasClass('open')) {
          $(this).find('input').val('').focus();
          $(this).find('.input-group-btn>button').prop('disabled', true);
        }
      }
      return false;
    })
    modal.find('.sF-newDir input').on('keyup', function(e) {
      var disabled = $(this).val() == '';
      $(this).parent().find('button').prop('disabled', disabled);
      if (e.keyCode == 13) {
        createFolder($(this).val(), modal);
      } else if (e.keyCode == 27) {
        var parent = $(this).closest('.sF-newDir');
        parent.toggleClass('open', false)
          .find('button.sF-btn-newDir').toggleClass('active', true);
      }
    })
    modal.find('.sF-newDir ul').on('click', function() {
      return false;
    })
    modal.find('.sF-newDir ul button').on('click', function() {
      var name = $(this).closest('input-group').find('input').val();
      createFolder(name, modal);
    })
        
    // Filenaming
    modal.find('.sF-filenaming')
      .on('click', '.input-group-btn.sF-filetype', function() {
        $(this).toggleClass('open')
          .find('button').toggleClass('active');
        return false;
      })
      .on('click', '.input-group-btn.sF-filetype li', function() {
        selectFiletype($(this));
        modal.trigger('change');
      })
    modal.find('.sF-filename').on('input', function() {
      modal.trigger('change');
    })

    // Custom events
    modal
      .on('change', function() {
        setDisabledButtons(button, modal);
        evalFilename(modal);
      })
      .on('fileSort', function(elem, attribute, direction) {
        $(button).data('sort', attribute).data('sortDir', direction);
        sortFiles(modal, attribute, direction);
      });
        
        
    // Binding data
    modal.data('backdrop', backdrop);
    modal.data('button', button);
    $(button).data('modal', modal);
    
    // Setting states
    var view = $(button).data('view') || 'sF-btn-icon';
    changeView(button, modal, modal.find('#'+view));
    modal.find('.sF-filename').focus();
    
    // Ready to enter
    setTimeout(function() {
      modal.addClass('in');
      backdrop.addClass('in');
    }, 1);
    
    populateFileChooser(button, $(button).data('dataCache'));
  };
    
  var addFiletypeChoice = function(button, modal) {
    var filetypes = $(button).data('filetype');
    var inputGroup = $(modal).find('.sF-filenaming');
    
    if(filetypes.length == 1) {
      if(filetypes[0] == null) return;
      inputGroup.append(
        $('<span>', {text: filetypes[0].ext[0]})
          .addClass('input-group-addon sF-filetype')
          .data('filetype', filetypes[0])
      )
    } else {
      inputGroup.append(
        $('<div>').addClass('input-group-btn sF-filetype').append(
          $('<button>', {type: 'button'}).addClass('btn btn-default dropdown-toggle')
        ).append(
          $('<ul>', {role: 'menu'}).addClass('dropdown-menu dropdown-menu-right')
        )
      );
      var typeSelect = inputGroup.find('.sF-filetype ul');
      filetypes.forEach(function(d, i) {
        typeSelect.append(
          $('<li>').append(
            $('<a>', {href: '#', text: d.name+' ('+d.ext.join(', ')+')'})
          ).data('filetype', d)
        )
      })
      selectFiletype(typeSelect.find('li:first-child'));
    }
  }
    
  var selectFiletype = function(element) {
    var button = element.closest('.sF-filetype').children('button');
    var filetype = element.data('filetype');
    
    button.text(filetype.ext[0] + ' ').append(
      $('<span>').addClass('caret')
    );
    element.closest('.sF-filetype').data('filetype', filetype);
  }
    
  var getFilename = function(modal) {
    var name = modal.find('.sF-filename').val();
    var type = null;
    
    if(name != '') {
      var filetype = modal.find('.sF-filetype').data('filetype');
      if(filetype !== undefined) {
        var hasExt = filetype.ext.some(function(d) {
          var regex = new RegExp(d+'$', 'i');
          return regex.test(name)
        });
        if(!hasExt) {
          name = name + filetype.ext[0];
        }
        type = filetype.name;
      }
    }
    
    return {name: name, type: type};
  }
    
  var evalFilename = function(modal) {
    var parent = modal.find('.sF-filenaming');
    var name = getFilename(modal).name;
    modal.find('#sF-selectButton').prop('disabled', name == '' || modal.find('.sF-permission').length != 0);
    if(nameExist(modal, name)) {
      parent.toggleClass('has-feedback', true)
        .toggleClass('has-warning', true);
      if(parent.find('#filenameWarn').length == 0) {
        parent.find('.sF-filename').after(
          $('<span>', {id: 'filenameWarn'}).addClass('glyphicon glyphicon-warning-sign form-control-feedback')
        )
      }
      modal.find('#sF-selectButton').text('Overwrite')
        .toggleClass('btn-primary', false)
        .toggleClass('btn-warning', true)
    } else {
      parent.toggleClass('has-feedback', false)
        .toggleClass('has-warning', false);
      parent.find('#filenameWarn').remove()
      modal.find('#sF-selectButton').text('Save')
        .toggleClass('btn-primary', true)
        .toggleClass('btn-warning', false)
    }
  }
    
  var nameExist = function(modal, name) {
    var files = modal.find('.sF-file .sF-file-name div').map(function() {return $(this).text()}).get();
    return files.indexOf(name) != -1;
  }
    
  var setFilename = function(modal, name) {
    var filetype = modal.find('.sF-filetype').data('filetype');
    var extRegex = /\.[^.]*$/;
    var removeExt = false;
    if(filetype !== undefined) {
      var hasExt = filetype.ext.map(function(d) {
        var regex = new RegExp(d+'$', 'i');
        return regex.test(name)
      });
      if(hasExt.some(function(d) {return d;})) {
        if(hasExt[0]) {
          removeExt = true;
        }
      } else {
        removeExt = true;
      }
    }
    if(removeExt) {
      name = name.replace(extRegex, '');
    }
    modal.find('.sF-filename').val(name);
    modal.trigger('change');
  }
    
  var saveFile = function(modal, button) {
    var dir = getCurrentDirectory(modal);
    var file = getFilename(modal);
    $.extend(file, dir);
    
    $(button).data('file', file);
    
    removeFileChooser(button, modal, file);
  }
  // File saver ends
    
  // Directory chooser
  var createDirChooser = function(button, title) {
        
    // Preparations
    $(button).prop('disabled', true);
    
    initializeButton(button);
          
    // Create the dialog
    var modal = $('<div>', {id: $(button).attr('id')+'-modal'}).addClass('sF-modalContainer modal fade').css('display', 'block'  ).append(
      $('<div>').addClass('sF-modal modal-dialog').append(
        $('<div>').addClass('modal-content').append(
          $('<div>').addClass('modal-header').append(
            $('<button>', {html: '&times;', type: 'button'}).addClass('close')
          ).append(
            $('<h4>', {text: title}).addClass('sF-title modal-title')
          )
        ).append(
          $('<div>').addClass('modal-body').append(
            $('<div>').addClass('sF-navigation btn-toolbar').append(
              $('<div>').addClass('sF-newDir dropdown btn-group btn-group-sm').append(
                $('<button>', {id: 'sF-btn-newDir', text: ' Create new folder'}).addClass('btn btn-default dropdown-toggle'  ).prepend(
                  $('<span>').addClass('glyphicon glyphicon-folder-close')
                )
              ).append(
                $('<ul>').addClass('dropdown-menu').append(
                  $('<li>').append(
                    $('<div>').addClass('input-group input-group-sm').append(
                      $('<input>', {type: 'text', placeholder: 'Folder name', spellcheck: 'false'}).addClass('form-control')
                    ).append(
                      $('<span>').addClass('input-group-btn').append(
                        $('<button>', {type: 'button'}).addClass('btn btn-default').prop('disabled', true).append(
                          $('<span>').addClass('glyphicon glyphicon-plus-sign')    
                        )
                      )
                    )
                  )
                )
              )
            ).append(
              $('<div>').addClass('sF-sort dropdown btn-group btn-group-sm').append(
                $('<button>', {id: 'sF-btn-sort', text: ' Sort content'}).addClass('btn btn-default dropdown-toggle').prepend(
                  $('<span>').addClass('glyphicon glyphicon-sort-by-attributes')
                )
              ).append(
                $('<ul>').addClass('dropdown-menu').append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', {href: '#', text: 'Name'}).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Name' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', {href: '#', text: 'Type'}).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Type' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', {href: '#', text: 'Size'}).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Size' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('divider')
                ).append(
                  $('<li>').addClass('sortDir').append(
                    $('<a>', {href: '#', text: 'Sort direction'}).addClass($(button).data('sortDir')).prepend($('<span>').addClass  ('glyphicon glyphicon-arrow-down')).prepend($('<span>').addClass('glyphicon glyphicon-arrow-up'))
                  )
                )
              )
            ).append(
              $('<select>').addClass('sF-breadcrumps form-control input-sm')
            )
          ).append(
            $('<div>').addClass('sF-dirWindow').append(
              $('<div>').addClass('sF-dirInfo col-md-7').append(
                $('<h6>', {text: 'Directories'})
              ).append(
                $('<div>').append(
                  $('<div>').addClass('sF-dirList').append(
                    $('<div>')
                  )
                )
              )
            ).append(
              $('<div>').addClass('sF-dirInfo col-md-5').append(
                $('<h6>', {text: 'Content'})
              ).append(
                $('<div>').append(
                  $('<div>').addClass('sF-dirContent')
                )
              )
            )
          )
        ).append(
          $('<div>').addClass('sF-responseButtons modal-footer').append(
            $('<button>', {text: 'Cancel', type: 'button', id: 'sF-cancelButton'}).addClass('btn btn-default')
          ).append(
            $('<button>', {text: 'Select', type: 'button', id: 'sF-selectButton'}).addClass('btn btn-primary')
          )
        )
      )
    ).appendTo($('body'));
          
    var backdrop = $('<div>')
      .addClass('sF-modalBackdrop modal-backdrop fade')
      .appendTo($('body'));
              
    // HANDLER FUNCTION ATTACHMENT
          
    // Dismissers and selecters
    modal.find('.modal-header button.close').on('click', function() {
      dismissFileChooser(button, modal)
    })
    modal.find('.sF-responseButtons #sF-cancelButton').on('click', function() {
      dismissFileChooser(button, modal);
    })
    modal.find('.sF-responseButtons #sF-selectButton').on('click', function() {
      selectFiles(button, modal);
    })
          
    // Create dir
    modal.find('.sF-newDir').on('click', function() {
      var disabled = $(this).find('button').prop('disabled')
      if(!disabled) {
        $(this).toggleClass('open')
          .find('button.sF-btn-newDir').toggleClass('active');
        if($(this).hasClass('open')) {
          $(this).find('input').val('').focus();
          $(this).find('.input-group-btn>button').prop('disabled', true);
        }
      }
      return false;
    })
    modal.find('.sF-newDir input').on('keyup', function(e) {
      var disabled = $(this).val() == '';
      $(this).parent().find('button').prop('disabled', disabled);
      if(e.keyCode == 13) {
        createFolder($(this).val(), modal);
      } else if(e.keyCode == 27) {
        var parent = $(this).closest('.sF-newDir');
        parent.toggleClass('open', false)
          .find('button.sF-btn-newDir').toggleClass('active', true);
      }
    })
    modal.find('.sF-newDir ul').on('click', function() {
      return false;
    })
    modal.find('.sF-newDir ul button').on('click', function() {
      var name = $(this).closest('.input-group').find('input').val();
      createFolder(name, modal);
    })
          
    // Sort content
    modal.find('.sF-sort').on('click', function() {
      $(this).toggleClass('open')
        .find('button').toggleClass('active');
      return false;
    })
    modal.find('.sF-sort ul')
      .on('click', 'li.sortAttr', function() {
        $(this).siblings('.sortAttr').removeClass('selected');
        $(this).toggleClass('selected', true);
        $(modal).trigger('fileSort', [$(this).find('a').text(), $(this).siblings('.sortDir').find('a').attr('class')])
      })
      .on('click', 'li.sortDir', function() {
        $(this).find('a').toggleClass('ascending').toggleClass('descending')
        $(modal).trigger('fileSort', [$(this).parent().find('.selected a').text(), $(this).find('a').attr('class')])
      })
          
    // Set volume
    modal.find('.sF-breadcrumps').on('change', function() {
      changeVolume($(this).val(), modal);
    })
          
    // Directory tree
    modal.find('.sF-dirList')
      .on('click', '.sF-expander>span', function(e) {
        toggleExpander($(this), modal, button);
      })
      .on('click', '.sF-file-icon, .sF-file-name', function(e) {
        selectFolder($(this), modal, button);
      })
    
    // Custom events
    modal
      .on('change', function() {
        setDisabledButtons(button, modal);
      })
      .on('fileSort', function(elem, attribute, direction) {
        $(button).data('sort', attribute).data('sortDir', direction);
        sortFiles(modal, attribute, direction);
      });
      
    // Attach relevant data
    modal.data('backdrop', backdrop);
    modal.data('button', button);
    $(button).data('modal', modal);
      
    // Set relevant states
    var view = $(button).data('view') || 'sF-btn-icon';
    changeView(button, modal, modal.find('#'+view));
          
    // Ready to enter
    setTimeout(function() {
      modal.addClass('in');
      backdrop.addClass('in');
    }, 1);
      
    populateDirChooser(button, $(button).data('dataCache'));
  };
    
  var populateDirChooser = function(element, data) {
    var modal = $(element).data('modal');
      
    $(element).data('dataCache', data);
      
    if(!modal || !data) return;
        
    var currentData = modal.data('currentData');
    
    var dirTree = modal.find('.sF-dirList>div');
    
    updateTree(dirTree, data.tree, data.contentPath);
    
    dirTree.addClass('root').children('.sF-file-name').children().text(data.selectedRoot);
    
    var breadcrumps = modal.find('.sF-breadcrumps')
    breadcrumps.find('option, optgroup').remove();
    
    var rootList = $('<optgroup>', {label: 'Volumes'}).appendTo(breadcrumps);
    data.rootNames.forEach(function(d) {
      rootList.append(
        $('<option>', {text: d})
      )
    })
    breadcrumps.val(data.selectedRoot);
        
    var dirContent = modal.find('.sF-dirContent');
    dirContent.addClass('measuring').children().remove();
        
    if(data.content == null) {
      dirContent.toggleClass('message', true).append(
        $('<div>').text('No folder selected')
      );
    } else if(data.content.filename.length == 0) {
      dirContent.toggleClass('message', true).append(
        $('<div>').text('Empty folder')
      );
    } else {
      dirContent.toggleClass('message', false)
      data.content.filename.forEach(function(file, i) {
        var d = {
          name: file,
          isDir: data.content.isdir[i],
          extension: data.content.extension[i],
          size: data.content.size[i]
        };
        dirContent.append(
          $('<div>').toggleClass('sF-file', !d.isDir).toggleClass('sF-directory', d.isDir).append(
            $('<div>').addClass('sF-file-icon').addClass('sF-filetype-'+d.extension)
          ).append(
            $('<div>').addClass('sF-file-name').append(
              $('<div>',  {text: d.name})
            )
          ).append(
            $('<div>', {text: d.isDir ? '' : formatSize(d.size, true)}).addClass('sF-file-size')
          ).data('sF-file', d)
        );
      })
    }
    var sizeCell = dirContent.find('.sF-file-size');
    var width = Math.max.apply(null, sizeCell.map(function() {return $(this).width()}));
    sizeCell.css('width', width+'px');
    dirContent.removeClass('measuring');
    
    toggleSelectButton(modal);
    setPermission(modal, data.writable);
    
    modal.data('currentData', data);
    $(modal).trigger('change');
  };
    
  var updateTree = function(element, tree, selectPath) {
    var selected = false;
    var childSelection = null;
    element.toggleClass('sF-directory', true);
    if(selectPath != null) {
      if(selectPath[0] == tree.name) {
        if(selectPath.length == 1) {
          selected = true;
          selectPath = null;
        } else {
          selectPath = selectPath.slice(1);
        }
      } else {
        selectPath = null;
      }
    }
    element.toggleClass('selected', selected);
    element.toggleClass('empty', tree.empty);
    if(tree.empty) {
      element.removeClass('expanded closed');
    } else {
      element.toggleClass('expanded', tree.expanded);
      element.toggleClass('closed', !tree.expanded);
    }
        
    if(element.children().length == 0) {
      element.append(
        $('<div>').addClass('sF-expander').append(
          $('<span>').addClass('glyphicon glyphicon-chevron-right')
        )
      ).append(
        $('<div>').addClass('sF-file-icon')
      ).append(
        $('<div>').addClass('sF-file-name').append(
          $('<div>', {text: tree.name})
        )
      ).append(
        $('<div>').addClass('sF-content')
      )
    }
    if(!tree.expanded) {
      element.children('.sF-content').children().remove();
    } else {
      var parent = element.children('.sF-content');
      var children = parent.children();
      var oldChildren = [];
      var removedChildren = [];
      children.each(function(index) {
        var childElem = $(this);
        var childName = childElem.children('.sF-file-name').children().text();
        var remove = true;
        for(var i = 0; i < tree.children.length; i++) {
          if(childName == tree.children[i].name) {
            updateTree(childElem, tree.children[i], selectPath);
            oldChildren.push(i);
            remove = false;
            break;
          }
        }
        if(remove) removedChildren.push(index);
      })
      tree.children.forEach(function(val, i) {
        if(oldChildren.indexOf(i) == -1) {
          var newBranch = $('<div>');
          updateTree(newBranch, val, selectPath);
          newBranch.appendTo(parent);
        }
      })
      var removedElements = children.filter(function(i) {return removedChildren.indexOf(i) != -1;});
      removedElements.remove();
      var currentChildren = parent.children();
      currentChildren.detach().sort(function(a, b) {
        var comp = $(a).find('.sF-file-name>div').text().toLowerCase() < $(b).find('.sF-file-name>div').text().toLowerCase();
        return comp ? -1 : 1;
      })
      parent.append(currentChildren);
    }
  };
    
  var selectFolder = function(element, modal, button) {
    var deselect = element.closest('.sF-directory').hasClass('selected');
    var list = element.closest('.sF-dirList');
    list.find('.selected').toggleClass('selected');
        
    if(deselect) {
      var path = null;
    } else {
      var path = getPath(element);
      element.closest('.sF-directory').toggleClass('selected');
    }
        
    setDisabledButtons(button, modal);
    toggleSelectButton(modal);
        
    modal.data('currentData').contentPath = path;
    Shiny.onInputChange($(button).attr('id')+'-modal', modal.data('currentData'));
        
    return false;
  };
    
  var toggleExpander = function(element, modal, button) {
    var parent = element.closest('.sF-directory');
    if(!parent.hasClass('empty')) {
      var path = getPath(element);
      if(parent.find('.selected').length != 0) {
        modal.data('currentData').contentPath = path.slice();
      }
      path.shift();
      var tree = modal.data('currentData').tree;
      while(true) {
        if(path.length == 0) {
          tree.expanded = !tree.expanded;
          break;
        } else {
          var name = path.shift();
          tree = tree.children.filter(function(f) {
            return f.name == name;
          })[0];
        }
      }
      Shiny.onInputChange($(button).attr('id')+'-modal', modal.data('currentData'));
    }
    return false;
  };
    
  var createFolder = function(name, modal) {
    if(name != '') {
      var button = $($(modal).data('button'));
            
      if(button.hasClass('shinySave')) {
        var directory = getCurrentDirectory(modal);
        var path = directory.path;
        var root = directory.root;
        var locationData = {
          path: path.concat([name]),
          root: root
        }
        changeDirectory(button, modal, locationData)
      } else {
        var directory = modal.find('.sF-dirList .selected');
        if(directory.length != 1) return
        var path = getPath(directory);
        var root = modal.data('currentData').selectedRoot;
      }
      var id = new Date();
      var data = {
        name: name,
        path: path,
        root: root,
        id: id.getTime()
      }
      Shiny.onInputChange(button.attr('id')+'-newDir', data);
      $(modal).find('.sF-newDir').toggleClass('open', false)
        .find('.sF-btn-newDir').toggleClass('active', false);
    }
  };
    
  var getPath = function(element) {
    if(element.hasClass('.sF-directory')) {
      var parent = element;
    } else {
      var parent = element.closest('.sF-directory');
    }
    
    var path = [parent.children('.sF-file-name').children().text()];
    while(true) {
      parent = parent.parent().parent();
      if(!parent.hasClass('sF-directory')) break;
      path.push(parent.children('.sF-file-name').children().text());
    };
    path.reverse();
    path[0] = '';
    return path;
  };
    
  var changeVolume = function(volume, modal) {
    var button = $(modal).data('button');
    var data = $(modal).data('currentData');
    
    data.selectedRoot = volume;
    data.content = null;
    data.contentPath = null;
    data.tree = {
      name: '',
      expanded: true
    };
    
    Shiny.onInputChange($(button).attr('id')+'-modal', data);
  };
  // Directory chooser ends
    
  var sF = {};
  
  sF.init = function() {
    Shiny.addCustomMessageHandler('shinyFiles', function(data) {
      populateFileChooser($('.shinyFiles#'+data.id), parseFiles(data.dir));
    });
    Shiny.addCustomMessageHandler('shinyDirectories', function(data) {
      populateDirChooser($('.shinyDirectories#'+data.id), data.dir);
    });
    Shiny.addCustomMessageHandler('shinySave', function(data) {
      populateFileChooser($('.shinySave#'+data.id), parseFiles(data.dir));
    });
    
    $(document).on('click', '.shinyFiles', function(e) {
      createFileChooser(this, $(this).data('title'));
    }).on('click', function(e) {
      $('.sF-modal .open').removeClass('open').find('button').removeClass('active');
    });
        
    $(document).on('click', '.shinyDirectories', function(e) {
      createDirChooser(this, $(this).data('title'));
    }).on('click', function(e) {
      $('.sF-modal .open').removeClass('open').find('button').removeClass('active');
    });
        
    $(document).on('click', '.shinySave', function(e) {
      createFileSaver(this, $(this).data('title'));
    }).on('click', function(e) {
      $('.sF-modal .open').removeClass('open').find('button').removeClass('active');
    });
  };
  
  return sF;
})();

$(document).ready(function() {
  shinyFiles.init();
});
