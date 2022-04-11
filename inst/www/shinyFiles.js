var shinyFiles = (function () {
  // General functionality

  var elementSelector = function (event, element, single, forceSelect) {
    var parent = $(element).parent();
    var lastSelectedElement = parent.data('lastElement');

    function toggleSelection(element) {
      $(element).toggleClass('selected');
      parent.data('lastElement', element);
      toggleSelectButton($('.sF-modalContainer'));
    }

    function selectElementsBetweenIndexes(indexes) {
      var els = parent.children();
      indexes.sort(function (a, b) {
        return a - b;
      });

      clearAll();

      for (var i = indexes[0]; i <= indexes[1]; i++) {
        $(els[i]).addClass('selected');
      }
    }

    function clearAll() {
      parent.children().removeClass('selected');
    }

    function scrollToSelected() {
      // Adjust for any overall offsets
      // Adjustments depend on what kind of modal/display is present
      var modal = $('.sF-modalContainer');
      var button = $(modal.data('button'));
      var fileFlag = button.hasClass('shinyFiles');
      var saveFlag = button.hasClass('shinySave');

      if (fileFlag || saveFlag) {
        // Different display modes handled differently for file/save modal
        var viewType = button.data('view');

        if (viewType === "sF-btn-icon") {
          // Vertical scroll
          var topOffset = $(element)[0].offsetTop - parent.children()[1].offsetTop;
          var scrollPosition = $('.sF-fileWindow')[0].scrollTop;

          if (topOffset < scrollPosition) {
            $('.sF-fileWindow')[0].scrollTop = topOffset;
          } else if (topOffset + $(element).outerHeight(true) > scrollPosition + $('.sF-fileWindow').height()) {
            $('.sF-fileWindow')[0].scrollTop = topOffset - $('.sF-fileWindow').height() + $(element).outerHeight(true);
          }
        } else if (viewType === "sF-btn-list") {
          // Lists scroll horizontally, but otherwise the logic is very similar to icons
          var leftOffset = $(element)[0].offsetLeft - parent.children()[1].offsetLeft;
          var scrollPosition = $('.sF-fileWindow')[0].scrollLeft;

          if (leftOffset < scrollPosition) {
            $('.sF-fileWindow')[0].scrollLeft = leftOffset;
          } else if (leftOffset + $(element).outerWidth(true) > scrollPosition + $('.sF-fileWindow').width()) {
            $('.sF-fileWindow')[0].scrollLeft = leftOffset - $('.sF-fileWindow').width() + $(element).outerWidth(true);
          }
        } else if (viewType === "sF-btn-detail") {
          // Essentially the same as icons, but header is visible
          var topOffset = $(element)[0].offsetTop - parent.children()[0].offsetTop;
          var scrollPosition = $('.sF-fileWindow')[0].scrollTop;

          if (topOffset < scrollPosition) {
            $('.sF-fileWindow')[0].scrollTop = topOffset;
          } else if (topOffset + $(element).outerHeight(true) > scrollPosition + $('.sF-fileWindow').height()) {
            $('.sF-fileWindow')[0].scrollTop = topOffset - $('.sF-fileWindow').height() + $(element).outerHeight(true)
          }
        }
      } // NOTE: Selection in dirchooser is handled by selectFolder. Submission is handled by selectFiles
    }

    // Use the same selector event for arrow key navigation
    if (event.button === 0 || event.type === "keydown") {
      if ((!event.metaKey && !event.ctrlKey && !event.shiftKey) || single) {
        var selected = $(element).hasClass('selected');
        var nSelected = parent.children('.selected').length;
        clearAll();
        if ((!selected || nSelected != 1) || forceSelect) {
          toggleSelection(element);
          scrollToSelected();
        }
      } else if ((event.metaKey || event.ctrlKey) && !single) {
        toggleSelection(element);
        scrollToSelected();
      } else if (event.shiftKey && !single) {
        selectElementsBetweenIndexes([$(lastSelectedElement).index(), $(element).index()]);
        scrollToSelected();
      }
    }
  };

  var moveSelection = function (event, single, direction) {
    var modal = $('.sF-modalContainer');
    var button = $(modal.data('button'));
    var fileFlag = button.hasClass('shinyFiles');
    var saveFlag = button.hasClass('shinySave');
    var dirFlag = button.hasClass('shinyDirectories');

    if (fileFlag || saveFlag) {
      var parent = $(".sF-fileList");
      var currentElement = parent.data('lastElement');
      var selectionEnd;
      if ('selectionEnd' in parent.data() && parent.data('selectionEnd') !== null) {
        selectionEnd = parent.data('selectionEnd');
      } else {
        // For the purposes of selecting next/previous elements,
        //    consider a single selected item to be both the
        //    first and last item in a selection of multiple items.
        selectionEnd = currentElement;
      }

      // No element is currently selected, return without action
      // if (!$(currentElement).hasClass('selected')) {
      if (!('lastElement' in parent.data())
        || parent.data('lastElement') === null
        || !$(parent.data('lastElement')).is(":visible")) {
        // Start on the first element if none are currently selected.
        var newElement = parent.children()[1];
        elementSelector(event, newElement, single, true);
        return;
      }

      var originIndex = $(currentElement).index(); // The original selected icon
      var endIndex = $(selectionEnd).index();      // The end that moves for multi-selection
      var ends = [originIndex, endIndex].sort();

      // Number of icons that fit with the file list, left to right
      var boundingWidth = $(".sF-fileWindow").width();
      var boundingHeight = $(".sF-fileWindow").height();
      var itemWidth = $(parent.children()[1]).outerWidth(true);
      var itemHeight = $(parent.children()[1]).outerHeight(true);
      var numHorizontal = Math.floor(boundingWidth / itemWidth);
      var numVertical = Math.floor(boundingHeight / itemHeight);
      var lastItemIndex = parent.children().length - 1;  // Subtract 1 to account for header

      var viewType = button.data('view');
      var bounds = {};

      var invalidFlag = false;

      var newIndex;

      // NOTE: The appropriate left/right/up/down position depends on whether shift is held
      // Dealing with a multi-selection
      if (!single && event.shiftKey) {
        if (viewType === "sF-btn-icon") {
          bounds = {
            left: Math.max(((Math.ceil(endIndex / numHorizontal) - 1) * numHorizontal) + 1, 1),
            right: Math.min(Math.ceil(endIndex / numHorizontal) * numHorizontal, lastItemIndex),
            up: 1,
            down: lastItemIndex
          };
        } else if (viewType === "sF-btn-list") {
          bounds = {
            left: 1,
            right: lastItemIndex,
            up: Math.max(((Math.ceil(endIndex / numVertical) - 1) * numVertical) + 1, 1),
            down: Math.min(Math.ceil(endIndex / numVertical) * numVertical, lastItemIndex)
          };
        } else if (viewType === "sF-btn-detail") {
          bounds = {
            left: 1,
            right: lastItemIndex,
            up: 1,
            right: lastItemIndex
          };
        }

        newIndex = endIndex;

        // Find new index, if valid, based on movement direction.
        //    Does not move the original anchor, regardless of which item comes first in the list.
        if (viewType === "sF-btn-icon") {
          switch (direction) {
            case "left":
              newIndex = endIndex - 1;
              if (newIndex < bounds.left) { invalidFlag = true; }
              break;
            case "right":
              newIndex = endIndex + 1;
              if (newIndex > bounds.right) { invalidFlag = true; }
              break;
            case "up":
              newIndex = endIndex - numHorizontal;
              if (newIndex < bounds.up) { invalidFlag = true; }
              break;
            case "down":
              newIndex = endIndex + numHorizontal;
              if (newIndex > bounds.down) { invalidFlag = true; }
              break;
          }
        } else if (viewType === "sF-btn-list") {
          switch (direction) {
            case "left":
              newIndex = endIndex - numVertical;
              if (newIndex < bounds.left) { invalidFlag = true; }
              break;
            case "right":
              newIndex = endIndex + numVertical;
              if (newIndex > bounds.right) { invalidFlag = true; }
              break;
            case "up":
              newIndex = endIndex - 1;
              if (newIndex < bounds.up) { invalidFlag = true; }
              break;
            case "down":
              newIndex = endIndex + 1;
              if (newIndex > bounds.down) { invalidFlag = true; }
              break;
          }
        } else if (viewType === "sF-btn-detail") {
          switch (direction) {
            case "left":
              invalidFlag = true;
              break;
            case "right":
              invalidFlag = true;
              break;
            case "up":
              newIndex = endIndex - 1;
              if (newIndex < bounds.up) { invalidFlag = true; }
              break;
            case "down":
              newIndex = endIndex + 1;
              if (newIndex > bounds.down) { invalidFlag = true; }
              break;
          }
        }
      } else {
        if (viewType === "sF-btn-icon") {
          bounds = {
            left: Math.max(((Math.ceil(ends[0] / numHorizontal) - 1) * numHorizontal) + 1, 1),
            right: Math.min(Math.ceil(ends[1] / numHorizontal) * numHorizontal, lastItemIndex),
            up: 1,
            down: lastItemIndex
          };
        } else if (viewType === "sF-btn-list") {
          bounds = {
            left: 1,
            right: lastItemIndex,
            up: Math.max(((Math.ceil(ends[0] / numVertical) - 1) * numVertical) + 1, 1),
            down: Math.min(Math.ceil(ends[1] / numVertical) * numVertical, lastItemIndex)
          };
        } else if (viewType === "sF-btn-detail") {
          bounds = {
            left: 1,
            right: lastItemIndex,
            up: 1,
            down: lastItemIndex,
          };
        }

        // Slightly different behavior when switching to a single selection
        //    Left and Up move from the first item (index: ends[0])
        //    Right and Down move from the last item (index: ends[1])
        newIndex = originIndex;

        if (viewType === "sF-btn-icon") {
          switch (direction) {
            case "left":
              newIndex = ends[0] - 1;
              if (newIndex < bounds.left) { invalidFlag = true; }
              break;
            case "right":
              newIndex = ends[1] + 1;
              if (newIndex > bounds.right) { invalidFlag = true; }
              break;
            case "up":
              newIndex = endIndex - numHorizontal;
              if (newIndex < bounds.up) { invalidFlag = true; }
              break;
            case "down":
              newIndex = endIndex + numHorizontal;
              if (newIndex > bounds.down) { invalidFlag = true; }
              break;
          }
        } else if (viewType === "sF-btn-list") {
          switch (direction) {
            case "left":
              newIndex = ends[0] - numVertical;
              if (newIndex < bounds.left) { invalidFlag = true; }
              break;
            case "right":
              newIndex = ends[1] + numVertical;
              if (newIndex > bounds.right) { invalidFlag = true; }
              break;
            case "up":
              newIndex = ends[0] - 1;
              if (newIndex < bounds.up) { invalidFlag = true; }
              break;
            case "down":
              newIndex = ends[1] + 1;
              if (newIndex > bounds.down) { invalidFlag = true; }
              break;
          }
        } else if (viewType === "sF-btn-detail") {
          switch (direction) {
            case "left":
              invalidFlag = true;
              break;
            case "right":
              invalidFlag = true;
              break;
            case "up":
              newIndex = ends[0] - 1;
              if (newIndex < bounds.up) { invalidFlag = true; }
              break;
            case "down":
              newIndex = ends[1] + 1;
              if (newIndex > bounds.down) { invalidFlag = true; }
              break;
          }
        }
      }

      if (!invalidFlag) {
        var newElement = parent.children()[newIndex];
        elementSelector(event, newElement, single, true);

        if (button.hasClass("shinySave")) {
          if (!$(newElement).hasClass('sF-directory')) {
            var filename = $(newElement).find('.sF-file-name>div').text();
          } else {
            var filename = '';
          }

          setFilename(modal, filename);
        }

        if (!single && event.shiftKey) {
          // Preserve 'lastElement' during multi-selection, ensuring an anchor is consistent
          parent.data('lastElement', currentElement);
          parent.data('selectionEnd', newElement);
        } else {
          parent.data('selectionEnd', null);
        }
      }
    } else if (dirFlag) {
      var list = $('.sF-dirList');
      var currentElement = list.find('.selected');

      function nextSibling(elem) {
        return elem.next('.sF-directory.expanded,.sF-directory.closed,.sF-directory.empty');
      }

      function prevSibling(elem) {
        return elem.prev('.sF-directory.expanded,.sF-directory.closed,.sF-directory.empty');
      }

      function firstChild(elem) {
        var children = elem.find('.sF-directory.expanded,.sF-directory.closed,.sF-directory.empty');
        return $(children[0]);
      }

      function lastChild(elem) {
        var children = elem.find('.sF-directory.expanded,.sF-directory.closed,.sF-directory.empty');
        return $(children[children.length - 1]);
      }

      function parentDir(elem) {
        return $(elem.parents('.sF-directory.expanded,.sF-directory.closed,.sF-directory.empty')[0]);
      }

      if (currentElement.length != 1) {
        // No selection yet
        newElement = $(list.find('.sF-directory.expanded,.sF-directory.closed,.sF-directory.empty')[0]);
        selectFolder($(newElement[0]), modal, button);
        return;
      }

      var newElement = currentElement;

      switch (direction) {
        case "left":
          // Close if currently expanded
          if (currentElement.hasClass("expanded")) {
            // Close expanded directory
            toggleExpander($(currentElement.find('.sF-expander>span')[0]), modal, button);
            return;
          } else if (currentElement.hasClass("empty") || currentElement.hasClass("closed")) {
            newElement = $(parentDir(currentElement));
            selectFolder($(newElement[0]), modal, button);
            toggleExpander($($(parentDir(currentElement)).find('.sF-expander>span')[0]), modal, button);
            return;
          }

          break;
        case "right":
          // Open if currently not expanded
          if (currentElement.hasClass("closed")) {
            // Expand closed directory
            toggleExpander($(currentElement.find('.sF-expander>span')[0]), modal, button);
            return;
          } else {
            return;
          }

          break;
        case "up":
          // Navigate up (last child of previous sibling if open, previous sibling otherwise)
          var pSib = $(prevSibling(currentElement));
          if (pSib.length === 0) {
            // Navigate to parent. Will never have to go multiple levels at once for parent.
            newElement = parentDir(currentElement);
          } else if (pSib.hasClass('expanded')) {
            // Last child of previous sibling
            newElement = lastChild(pSib);
          } else {
            // Previous sibling
            newElement = pSib;
          }

          break;
        case "down":
          // Navigate down (first child if expanded, next sibling otherwise)
          var nSib = $(nextSibling(currentElement));
          if (currentElement.hasClass('expanded')) {
            // First child of current selection
            newElement = firstChild(currentElement);
          } else if (nSib.length === 0) {
            // Navigate to next sibling of closest ancestor that has a sibling
            var parDir = parentDir(currentElement);
            do {
              nSib = nextSibling(parDir);
              parDir = parentDir(parDir);
            } while (nSib.length === 0 && parDir.length > 0);

            newElement = nSib;
          } else {
            // Next sibling of current element
            newElement = nSib;
          }

          break;
      }

      if (newElement.length > 0) {
        selectFolder($(newElement[0]), modal, button);
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

    for (var i = 0, l = arrayA.length; i < l; i++) {
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

  vaobjSize = function (obj) {
    /*
    From http://stackoverflow.com/questions/5223/length-of-javascript-object-ie-associative-array answer by Jameglan
    */
    var size = 0, key;
    for (key in obj) {
      if (obj.hasOwnProperty(key)) size++;
    }
    return size;
  };

  $.fn.sortChildren = function (map, reverse) {
    /*
    Adapted from https://gist.github.com/rodneyrehm/2818576
    */
    var sortChildren = {
      // default comparison function using String.localeCompare if possible
      compare: function (a, b) {
        if ($.isArray(a.value)) {
          return sortChildren.compareList(a.value, b.value);
        }
        return sortChildren.compareValues(a.value, b.value);
      },

      compareValues: function (a, b) {
        if (typeof a === "string" && "".localeCompare) {
          return a.localeCompare(b);
        }

        return a === b ? 0 : a > b ? 1 : -1;
      },

      // default comparison function for DESC
      reverse: function (a, b) {
        return -1 * sortChildren.compare(a, b);
      },

      // default mapping function returning the elements' lower-cased innerTEXT
      map: function (elem) {
        return $(elem).text().toLowerCase();
      },

      // default comparison function for lists (e.g. table columns)
      compareList: function (a, b) {
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

    return this.each(function () {
      var $this = $(this),
        $children = $this.children(),
        _map = [],
        length = $children.length,
        i;

      for (i = 0; i < length; i++) {
        _map.push({
          index: i,
          value: (map || sortChildren.map)($children[i])
        });
      }

      _map.sort(reverse ? sortChildren.reverse : sortChildren.compare);

      for (i = 0; i < length; i++) {
        this.appendChild($children[_map[i].index]);
      }
    });
  };

  var parseFiles = function (data) {
    var parsedFiles = {};
    data.files.filename.forEach(function (d, i) {
      try {
        parsedFiles[d] = {
          name: d,
          extension: data.files.extension[i],
          isDir: data.files.isdir[i],
          size: data.files.size[i],
          mTime: new Date(data.files.mtime[i]),
          cTime: new Date(data.files.ctime[i]),
          aTime: new Date(data.files.atime[i])
        };
      } catch (err) {
        //This can happen if there is a broken link, for example
      }
    });

    return {
      files: parsedFiles,
      location: data.breadcrumps,
      writable: data.writable,
      exist: data.exist,
      rootNames: data.roots,
      selectedRoot: data.root,
      selectedFile: data.selectedFile
    };
  };

  var formatDate = function (date) {
    var monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    var dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    if (typeof Intl == 'undefined') {
      return dayNames[date.getDay()] + ' ' + monthNames[date.getMonth()] + ' ' + date.getDate() + ' ' + date.getFullYear() + ' ' + date.getHours() + ':' + ("0" + date.getMinutes()).substr(-2);
    } else {
      return date.toLocaleString([], { weekday: 'long', year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
    }
  };

  var formatSize = function (bytes, si) {
    /*
    This function is taken from http://stackoverflow.com/questions/10420352/converting-file-size-in-bytes-to-humeadable - Mark's answer    
    */
    var thresh = si ? 1000 : 1024;
    if (bytes < thresh) return bytes + ' B';
    var units = si ? ['kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'] : ['KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB'];
    var u = -1;
    do {
      bytes /= thresh;
      ++u;
    } while (bytes >= thresh);
    return bytes.toFixed(1) + ' ' + units[u];
  };

  var initializeButton = function (button) {
    var type = $(button).hasClass('shinyDirectories') ? 'directory' : 'file';
    var sort = $(button).data('sort') || 'Name';
    var sortDir = $(button).data('sortDir') || 'ascending';

    if (type == 'file') {
      var back = $(button).data('back') || [];
      var forward = $(button).data('forward') || [];
      var view = $(button).data('view') || '';
      $(button).data('back', back)
        .data('forward', forward)
        .data('view', view);
      if ($(button).hasClass('shinySave')) {
        var filetypes = $(button).data('filetype');
        filetypes.forEach(function (d) {
          if (d === null) return;
          d.ext = d.ext.map(function (ext) {
            return ext[0] == '.' ? ext : '.' + ext;
          });
        });
      }
    }
    $(button).data('sort', sort)
      .data('sortDir', sortDir);
  };

  var setDisabledButtons = function (button, modal) {
    var type = $(button).hasClass('shinyDirectories') ? 'directory' : 'file';

    if (type == 'file') {
      var back = $(button).data('back').length === 0;
      var forward = $(button).data('forward').length === 0;
      var up = $(modal).find('.sF-breadcrumps>option').length <= 1;

      $(modal).find('#sF-btn-back').prop('disabled', back);
      $(modal).find('#sF-btn-forward').prop('disabled', forward);
      $(modal).find('#sF-btn-up').prop('disabled', up);
    }
  };

  var filesSelected = function (modal) {
    var type = $($(modal).data('button')).hasClass('shinyDirectories') ? 'directory' : 'file';

    if (type == 'file') {
      return modal.find('.sF-fileList').children().filter('.sF-file.selected').length > 0;
    } else {
      return modal.find('.sF-dirList').find('.selected').length > 0;
    }
  };

  var toggleSelectButton = function (modal) {
    modal.find('#sF-selectButton').prop('disabled', !filesSelected(modal));
  };

  var sortFiles = function (modal, attribute, direction) {
    var type = $($(modal).data('button')).hasClass('shinyDirectories') ? 'directory' : 'file';
    var fileList;
    if (type == 'file') {
      fileList = $(modal).find('.sF-fileList');
    } else {
      fileList = $(modal).find('.sF-dirContent');
    }


    fileList.sortChildren(function (elem) {
      return $(elem).data('sF-file') ? $(elem).data('sF-file').name : '';
    }, direction == 'descending');

    if (attribute == 'Name') return;

    switch (attribute) {
      case 'Type':
        fileList.sortChildren(function (elem) {
          return $(elem).data('sF-file') ? $(elem).data('sF-file').isDir ? '000' : $(elem).data('sF-file').extension || '001' : '';
        }, direction == 'descending');
        break;
      case 'Size':
        fileList.sortChildren(function (elem) {
          return $(elem).data('sF-file') ? $(elem).data('sF-file').isDir ? -1 : $(elem).data('sF-file').size : 0;
        }, direction == 'descending');
        break;
      case 'Created':
        fileList.sortChildren(function (elem) {
          return $(elem).data('sF-file') ? $(elem).data('sF-file').cTime : new Date();
        }, direction == 'descending');
        break;
      case 'Modified':
        fileList.sortChildren(function (elem) {
          return $(elem).data('sF-file') ? $(elem).data('sF-file').mTime : new Date();
        }, direction == 'descending');
        break;
    }
  }

  var removeFileChooser = function (button, modal, data) {

    var modal = $(modal).removeClass('in');
    var backdrop = $(modal).data('backdrop').removeClass('in');

    setTimeout(function () {
      modal.remove();
      backdrop.remove();
      if (data !== undefined) {
        Shiny.onInputChange($(button).attr('id'), data);
      }
    }, 300);
    $(button).prop('disabled', false)
      .data('modal', null);
  };

  var dismissFileChooser = function (button, modal) {
    removeFileChooser(button, modal);
    $(button).trigger('cancel');
  };

  var selectFiles = function (button, modal) {
    var type = $(button).hasClass('shinyDirectories') ? 'directory' : 'file';

    if (type == 'file') {
      var files = getSelectedFiles(modal);
      $(button).data('files', files)
        .trigger('selection', [files])
        .trigger('fileselect', [files]);
      var data = {
        files: $.extend({}, files.files.toArray().map(function (d) {
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

  var setPermission = function (modal, writable) {
    var currentState = $(modal).find('.sF-warning').length == 0;
    var footer = $(modal).find('.modal-footer');
    var overwrite = $($(modal).data('button')).hasClass('shinySave') ? true : filesSelected(modal);

    $(modal).find('#sF-btn-newDir').prop('disabled', !(overwrite && writable));

    if (writable || !overwrite) {
      footer.find('.sF-warning').remove();
    } else if (currentState != writable) {
      footer.prepend(
        $('<div>').addClass('sF-warning text-warning').append(
          $('<span>').addClass('glyphicon glyphicon-warning-sign')
        ).append(
          $('<span>').text('No write permission for folder')
        )
      )
    }
  }

  var setExists = function (modal, exists) {
    var currentState = $(modal).find('.sF-warning').length == 0;
    var footer = $(modal).find('.modal-footer');

    $(modal).find('#sF-btn-newDir').prop('disabled', !(exists));


    footer.find('.sF-warning').remove();
    if (!exists) {
      footer.prepend(
        $('<div>').addClass('sF-warning text-warning').append(
          $('<span>').addClass('glyphicon glyphicon-warning-sign')
        ).append(
          $('<span>').text('Folder does not exist')
        )
      )
    }
  }

  // General functionality ends


  // File chooser
  var createFileChooser = function (button, title) {
    // Preparations

    $(button).prop('disabled', true);

    initializeButton(button);

    // Creating modal
    var modal = $('<div>', { id: $(button).attr('id') + '-modal' }).addClass('sF-modalContainer modal fade').css('display', 'block').append(
      $('<div>').addClass('sF-modal modal-dialog modal-lg').append(
        $('<div>').addClass('modal-content').append(
          $('<div>').addClass('modal-header').append(
            $('<h4>', { text: title }).addClass('sF-title modal-title')
          ).append(
            $('<button>', { html: '&times;', type: 'button' }).addClass('close')
          )
        ).append(
          $('<div>').addClass('modal-body').append(
            $('<div>').addClass('sF-navigation btn-toolbar').append(
              $('<div>').addClass('btn-group btn-group-sm sF-navigate').append(
                $('<button>', { id: 'sF-btn-back' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-chevron-left')
                )
              ).append(
                $('<button>', { id: 'sF-btn-up' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-arrow-up')
                )
              ).append(
                $('<button>', { id: 'sF-btn-forward' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-chevron-right')
                )
              )
            ).append(
              $('<div>').addClass('btn-group btn-group-sm sF-view').append(
                $('<button>', { id: 'sF-btn-icon' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-th')
                )
              ).append(
                $('<button>', { id: 'sF-btn-list' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-th-list')
                )
              ).append(
                $('<button>', { id: 'sF-btn-detail' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-align-justify')
                )
              )
            ).append(
              $('<div>').addClass('sF-sort dropdown btn-group btn-group-sm').append(
                $('<button>', { id: 'sF-btn-sort' }).addClass('btn btn-default dropdown-toggle').append(
                  $('<span>').addClass('glyphicon glyphicon-sort-by-attributes')
                )
              ).append(
                $('<ul>').addClass('dropdown-menu').append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Name' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Name' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Type' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Type' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Size' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Size' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Created' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Created' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Modified' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Modified' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('divider')
                ).append(
                  $('<li>').addClass('sortDir').append(
                    $('<a>', { href: '#', text: 'Sort direction' }).addClass($(button).data('sortDir')).prepend($('<span>').addClass('glyphicon glyphicon-arrow-down')).prepend($('<span>').addClass('glyphicon glyphicon-arrow-up'))
                  )
                )
              )
            ).append(
              $('<div>').addClass('sF-textChoice btn-group input-group-btn btn-group-sm').append(
                $('<button>', { id: 'sF-btn-textChoice', text: '' }).addClass('btn btn-default dropdown-toggle').prepend(
                  $('<span>').addClass('glyphicon glyphicon-pencil')
                )
              ).append(
                $('<ul>').addClass('dropdown-menu').append(
                  $('<li>').append(
                    $('<div>').addClass('input-group input-group-sm').append(
                      $('<input>', { type: 'text', placeholder: 'Enter Path' }).addClass('form-control')
                    ).append(
                      $('<span>').addClass('input-group-btn').append(
                        $('<button>', { type: 'button' }).addClass('btn btn-default').prop('disabled', true).append(
                          $('<span>').addClass('glyphicon glyphicon-ok-sign')
                        )
                      )
                    )
                  )
                )
              )
            ).append(
              $('<div>').addClass('sF-refresh btn-group btn-group-sm').append(
                $('<button>', { id: 'sF-btn-refresh' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-refresh')
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
            $('<button>', { text: 'Cancel', type: 'button', id: 'sF-cancelButton' }).addClass('btn btn-default')
          ).append(
            $('<button>', { text: 'Select', type: 'button', id: 'sF-selectButton' }).addClass('btn btn-primary')
          )
        )
      )
    ).appendTo($('body'));

    var backdrop = $('<div>')
      .addClass('sF-modalBackdrop modal-backdrop fade')
      .appendTo($('body'));

    // HANDLER BINDING

    // Dismissers and selecters
    modal.find('.modal-header button.close').on('click', function () {
      dismissFileChooser(button, modal)
    })

    modal.find('.sF-responseButtons #sF-cancelButton').on('click', function () {
      dismissFileChooser(button, modal);
    })
    modal.find('.sF-responseButtons #sF-selectButton').on('click', function () {
      selectFiles(button, modal);
    })

    // Button navigation
    modal.find('.sF-navigate #sF-btn-back').on('click', function () {
      moveBack(button, modal);
    })
    modal.find('.sF-navigate #sF-btn-up').on('click', function () {
      moveUp(button, modal);
    })
    modal.find('.sF-navigate #sF-btn-forward').on('click', function () {
      moveForward(button, modal);
    })

    // View changing
    modal.find('.sF-view').on('click', 'button', function () {
      changeView(button, modal, $(this));
    })

    // Sort content
    modal.find('.sF-sort').on('click', function () {
      $(this).toggleClass('open')
        .find('button').toggleClass('active');
      return false;
    })
    modal.find('.sF-sort ul')
      .on('click', 'li.sortAttr', function () {
        $(this).siblings('.sortAttr').removeClass('selected');
        $(this).toggleClass('selected', true);

        $(modal).trigger('fileSort', [$(this).find('a').text(), $(this).siblings('.sortDir').find('a').attr('class')])
      })
      .on('click', 'li.sortDir', function () {
        $(this).find('a').toggleClass('ascending').toggleClass('descending')

        $(modal).trigger('fileSort', [$(this).parent().find('.selected a').text(), $(this).find('a').attr('class')])
      })

    // Text Choice
    modal.find('.sF-textChoice').on('click', function () {
      var directory = getCurrentDirectory(modal);
      var disabled = $(this).find('button').prop('disabled')
      if (!disabled) {
        $(this).toggleClass('open')
          .find('button.sF-btn-textChoice').toggleClass('active');
        if ($(this).hasClass('open')) {
          $(this).find('input').val(directory.root + directory.path.join("/")).focus();
          $(this).find('.input-group-btn>button').prop('disabled', true);
        }
      }
      return false;
    })
    modal.find('.sF-textChoice input').on('keyup', function (e) {
      var disabled = $(this).val() == '';
      $(this).parent().find('button').prop('disabled', disabled);
      if (e.keyCode == 13) {
        e.stopPropagation();
        setPathFromTextInput($(this).val(), modal);
      } else if (e.keyCode == 27) {
        var parent = $(this).closest('.sF-textChoice');
        parent.toggleClass('open', false)
          .find('button.sF-btn-textChoice').toggleClass('active', true);
      }
    })
    modal.find('.sF-textChoice ul').on('click', function () {
      return false;
    })
    modal.find('.sF-textChoice ul button').on('click', function () {
      var name = $(this).closest('.input-group').find('input').val();
      setPathFromTextInput(name, modal);
    })

    // Breadcrump and volume navigation
    modal.find('.sF-breadcrumps').on('change', function () {
      moveToDir(button, modal, this);
    })

    // Refresh
    modal.find('.sF-refresh').on('click', function (event) {
      event.preventDefault();
      refreshDirectory(modal);
    })

    // File window
    modal.find('.sF-fileWindow')
      .on('click', function () {
        modal.find('.sF-fileList .selected').toggleClass('selected');
        toggleSelectButton(modal);
      })
      .on('dblclick', '.sF-file', function (event) {
        var single = $(button).data('selecttype') == 'single';
        elementSelector(event, this, single, true);
        selectFiles(button, modal);
      })
      .on('click', '.sF-file, .sF-directory', function (event) {
        var single = $(button).data('selecttype') == 'single';
        elementSelector(event, this, single, false);
        toggleSelectButton(modal);
        return false;
      })

    // Custom events
    modal
      .on('change', function () {
        setDisabledButtons(button, modal);
      })
      .on('fileSort', function (elem, attribute, direction) {
        $(button).data('sort', attribute).data('sortDir', direction);
        sortFiles(modal, attribute, direction);
      });


    // Binding data
    modal.data('backdrop', backdrop);
    modal.data('button', button);
    $(button).data('modal', modal);

    // Setting states
    var view = $(button).data('view') || 'sF-btn-icon';
    changeView(button, modal, modal.find('#' + view));

    // Ready to enter
    setTimeout(function () {
      if ($('#shiny-modal').length == 0) {
        modal.detach().appendTo('body')
      } else {
        modal.detach().appendTo('#shiny-modal')
      }
      modal.addClass('in');
      backdrop.addClass('in');
    }, 1);

    populateFileChooser(button, $(button).data('dataCache'), false);
  };

  var populateFileChooser = function (element, data, forceUpdate) {

    var modal = $(element).data('modal');

    $(element).data('dataCache', data);

    if (!modal) return;

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

    if (forceUpdate || newLocation || newVolumes) {
      if (!data) return;
      modal.find('.sF-breadcrumps').find('option, optgroup').remove();
      data.location.forEach(function (d, i) {
        modal.find('.sF-breadcrumps').prepend(
          $('<option>', { html: '&#128193; ' + (d || data.selectedRoot), value: d }).data('location', data.location.slice(0, i + 1))
        );
      });
      modal.find('.sF-breadcrumps').prop('selectedIndex', 0).data('selectedRoot', data.selectedRoot);

      var rootList = $('<optgroup>', { label: 'Volumes' }).appendTo(modal.find('.sF-breadcrumps'));
      data.rootNames.forEach(function (d) {
        rootList.append(
          $('<option>', { html: (d == data.selectedRoot ? '&#9679; ' : '&#9675; ') + d, value: d })
        )
      })
    };

    if (forceUpdate || newLocation) {
      modal.find('.sF-fileList').children().remove();

      modal.find('.sF-fileList').append(
        $('<div>').addClass('sF-file-header').append(
          $('<div>').append(
            $('<div>').addClass('sF-file-icon')
          ).append(
            $('<div>', { text: 'name' }).addClass('sF-file-name')
          ).append(
            $('<div>', { text: 'size' }).addClass('sF-file-size')
          ).append(
            $('<div>', { text: 'modified' }).addClass('sF-file-mTime')
          ).append(
            $('<div>', { text: 'created' }).addClass('sF-file-cTime')
          ).append(
            $('<div>', { text: 'accessed' }).addClass('sF-file-aTime')
          )
        )
      );

      for (i in data.files) {
        var d = data.files[i];

        modal.find('.sF-fileList').append(
          $('<div>').toggleClass('sF-file', !d.isDir).toggleClass('selected', d.name == data.selectedFile).toggleClass('sF-directory', d.isDir).append(
            $('<div>').addClass('sF-file-icon').addClass('sF-filetype-' + d.extension)
          ).append(
            $('<div>').addClass('sF-file-name').append(
              $('<div>', { text: d.name })
            )
          ).append(
            $('<div>', { text: d.isDir ? '' : formatSize(d.size, true) }).addClass('sF-file-size')
          ).append(
            $('<div>', { text: formatDate(d.mTime) }).addClass('sF-file-mTime')
          ).append(
            $('<div>', { text: formatDate(d.cTime) }).addClass('sF-file-cTime')
          ).append(
            $('<div>', { text: formatDate(d.aTime) }).addClass('sF-file-aTime')
          ).data('sF-file', d)
        );
      };
      modal.find('.sF-directory').on('dblclick', function () {
        $(this).toggleClass('selected', true);
        openDir($(element), modal, this);
      });
    } else {

      if (Object.keys(oldFiles).length === 0) {
        modal.find('.sF-fileList').children().filter(function () {
          return oldFiles[$(this).find('.sF-file-name div').text()]
        }).remove();
      };


      if (Object.keys(newFiles).length === 0) {
        for (i in newFiles) {
          var d = newFiles[i];

          modal.find('.sF-fileList').append(
            $('<div>').toggleClass('sF-file', !d.isDir).toggleClass('selected', d.name == data.selectedFile).toggleClass('sF-directory', d.isDir).append(
              $('<div>').addClass('sF-file-icon').addClass('sF-filetype-' + d.extension)
            ).append(
              $('<div>').addClass('sF-file-name').append(
                $('<div>', { text: d.name })
              )
            ).append(
              $('<div>', { text: d.isDir ? '' : formatSize(d.size, true) }).addClass('sF-file-size')
            ).append(
              $('<div>', { text: formatDate(d.mTime) }).addClass('sF-file-mTime')
            ).append(
              $('<div>', { text: formatDate(d.cTime) }).addClass('sF-file-cTime')
            ).append(
              $('<div>', { text: formatDate(d.aTime) }).addClass('sF-file-aTime')
            ).data('sF-file', d)
          );
        };
      };
    };

    if ($(element).hasClass('shinySave')) {
      setPermission(modal, data.writable);
      if (data.selectedFile != "") {
        setFilename(modal, data.selectedFile)
      }
    }
    setExists(modal, data.exist);
    toggleSelectButton(modal);

    modal.data('currentData', data);
    $(modal).trigger('change');
  };

  var getSelectedFiles = function (modal) {
    var directory = getCurrentDirectory(modal);

    return {
      files: modal.find('.sF-fileList').find('.selected .sF-file-name div').map(function () {
        var dirCopy = directory.path.slice();
        dirCopy.push($(this).text());
        return [dirCopy];
      }),
      root: directory.root
    };
  };

  var getCurrentDirectory = function (modal) {
    return {
      path: modal.find('.sF-breadcrumps>option').map(function () {
        return $(this).val();
      }).toArray().reverse(),
      root: modal.find('.sF-breadcrumps').data('selectedRoot')
    };
  };

  var changeView = function (button, modal, view) {
    modal.find('.sF-view button').toggleClass('active', false);
    view.toggleClass('active', true);

    var detail = false;
    var icons = false;
    var list = false;

    switch (view.attr('id')) {
      case 'sF-btn-icon':
        icons = true;
        break;
      case 'sF-btn-list':
        list = true;
        break;
      case 'sF-btn-detail':
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

  var changeDirectory = function (button, modal, directory) {
    if (directory.path instanceof jQuery) directory.path = directory.path.toArray();

    Shiny.onInputChange($(button).attr('id') + '-modal', directory);
  };

  var refreshDirectory = function (modal) {
    // Use timestamp to ensure change in value, triggering the backend observeEvent
    Shiny.onInputChange($(modal.data('button')).attr('id') + '-refresh', (new Date()).getTime());
  }

  var moveBack = function (button, modal) {
    $('.sF-btn-back').prop('disabled', true);

    var newDir = $(button).data('back').pop();
    var currentDir = getCurrentDirectory(modal);

    changeDirectory(button, modal, newDir);
    if (!$(button).data('forward')) {
      $(button).data('forward', []);
    }
    $(button).data('forward').push(currentDir);
  };

  var moveForward = function (button, modal) {
    $('.sF-btn-forward').prop('disabled', true);

    var newDir = $(button).data('forward').pop();
    var currentDir = getCurrentDirectory(modal);

    changeDirectory(button, modal, newDir);
    if (!$(button).data('back')) {
      $(button).data('back', []);
    }
    $(button).data('back').push(currentDir);
  };

  var moveUp = function (button, modal) {
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

  var moveToDir = function (button, modal, select) {
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

  var openDir = function (button, modal, dir) {
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
  var createFileSaver = function (button, title) {
    // Preparations

    $(button).prop('disabled', true);

    initializeButton(button);

    // Creating modal
    var modal = $('<div>', { id: $(button).attr('id') + '-modal' }).addClass('sF-modalContainer modal fade').css('display', 'block').append(
      $('<div>').addClass('sF-modal modal-dialog modal-lg').append(
        $('<div>').addClass('modal-content').append(
          $('<div>').addClass('modal-header').append(
            $('<h4>', { text: title }).addClass('sF-title modal-title')
          ).append(
            $('<button>', { html: '&times;', type: 'button' }).addClass('close')
          )
        ).append(
          $('<div>').addClass('modal-body').append(
            $('<div>').addClass('sF-navigation btn-toolbar').append(
              $('<div>').addClass('btn-group btn-group-sm sF-navigate').append(
                $('<button>', { id: 'sF-btn-back' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-chevron-left')
                )
              ).append(
                $('<button>', { id: 'sF-btn-up' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-arrow-up')
                )
              ).append(
                $('<button>', { id: 'sF-btn-forward' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-chevron-right')
                )
              )
            ).append(
              $('<div>').addClass('btn-group btn-group-sm sF-view').append(
                $('<button>', { id: 'sF-btn-icon' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-th')
                )
              ).append(
                $('<button>', { id: 'sF-btn-list' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-th-list')
                )
              ).append(
                $('<button>', { id: 'sF-btn-detail' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-align-justify')
                )
              )
            ).append(
              $('<div>').addClass('sF-sort dropdown btn-group btn-group-sm').append(
                $('<button>', { id: 'sF-btn-sort' }).addClass('btn btn-default dropdown-toggle').append(
                  $('<span>').addClass('glyphicon glyphicon-sort-by-attributes')
                )
              ).append(
                $('<ul>').addClass('dropdown-menu').append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Name' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Name' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Type' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Type' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Size' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Size' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Created' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Created' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Modified' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Modified' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('divider')
                ).append(
                  $('<li>').addClass('sortDir').append(
                    $('<a>', { href: '#', text: 'Sort direction' }).addClass($(button).data('sortDir')).prepend($('<span>').addClass('glyphicon glyphicon-arrow-down')).prepend($('<span>').addClass('glyphicon glyphicon-arrow-up'))
                  )
                )
              )
            ).append(
              $('<div>').addClass('sF-textChoice btn-group input-group-btn btn-group-sm').append(
                $('<button>', { id: 'sF-btn-textChoice', text: '' }).addClass('btn btn-default dropdown-toggle').prepend(
                  $('<span>').addClass('glyphicon glyphicon-pencil')
                )
              ).append(
                $('<ul>').addClass('dropdown-menu').append(
                  $('<li>').append(
                    $('<div>').addClass('input-group input-group-sm').append(
                      $('<input>', { type: 'text', placeholder: 'Enter Path' }).addClass('form-control')
                    ).append(
                      $('<span>').addClass('input-group-btn').append(
                        $('<button>', { type: 'button' }).addClass('btn btn-default').prop('disabled', true).append(
                          $('<span>').addClass('glyphicon glyphicon-ok-sign')
                        )
                      )
                    )
                  )
                )
              )
            ).append(
              $('<div>').addClass('sF-refresh btn-group btn-group-sm').append(
                $('<button>', { id: 'sF-btn-refresh' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-refresh')
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
                $('<button>', { id: 'sF-btn-newDir', text: ' Create new folder' }).addClass('btn btn-default dropdown-toggle').prepend(
                  $('<span>').addClass('glyphicon glyphicon-folder-close')
                )
              ).append(
                $('<ul>').addClass('dropdown-menu').append(
                  $('<li>').append(
                    $('<div>').addClass('input-group input-group-sm').append(
                      $('<input>', { type: 'text', placeholder: 'Folder name', spellcheck: 'false' }).addClass('form-control')
                    ).append(
                      $('<span>').addClass('input-group-btn').append(
                        $('<button>', { type: 'button' }).addClass('btn btn-default').prop('disabled', true).append(
                          $('<span>').addClass('glyphicon glyphicon-plus-sign')
                        )
                      )
                    )
                  )
                )
              )
            ).append(
              $('<input>', { type: 'text', value: $(button).attr('data-filename'), placeholder: 'filename', spellcheck: 'false' }).addClass('form-control sF-filename')
            )
          )
        ).append(
          $('<div>').addClass('sF-responseButtons modal-footer').append(
            $('<button>', { text: 'Cancel', type: 'button', id: 'sF-cancelButton' }).addClass('btn btn-default')
          ).append(
            $('<button>', { text: 'Save', type: 'button', id: 'sF-selectButton' }).addClass('btn btn-primary')
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
    modal.find('.modal-header button.close').on('click', function () {
      dismissFileChooser(button, modal)
    })
    modal.find('.sF-responseButtons #sF-cancelButton').on('click', function () {
      dismissFileChooser(button, modal);
    })
    modal.find('.sF-responseButtons #sF-selectButton').on('click', function () {
      saveFile(modal, button)
    })

    // Button navigation
    modal.find('.sF-navigate #sF-btn-back').on('click', function () {
      moveBack(button, modal);
    })
    modal.find('.sF-navigate #sF-btn-up').on('click', function () {
      moveUp(button, modal);
    })
    modal.find('.sF-navigate #sF-btn-forward').on('click', function () {
      moveForward(button, modal);
    })

    // View changing
    modal.find('.sF-view').on('click', 'button', function () {
      changeView(button, modal, $(this));
    })

    // Sort content
    modal.find('.sF-sort').on('click', function () {
      $(this).toggleClass('open')
        .find('button').toggleClass('active');
      return false;
    })
    modal.find('.sF-sort ul')
      .on('click', 'li.sortAttr', function () {
        $(this).siblings('.sortAttr').removeClass('selected');
        $(this).toggleClass('selected', true);

        $(modal).trigger('fileSort', [$(this).find('a').text(), $(this).siblings('.sortDir').find('a').attr('class')])
      })
      .on('click', 'li.sortDir', function () {
        $(this).find('a').toggleClass('ascending').toggleClass('descending')

        $(modal).trigger('fileSort', [$(this).parent().find('.selected a').text(), $(this).find('a').attr('class')])
      })

    // Refresh
    modal.find('.sF-refresh').on('click', function (e) {
      e.preventDefault();
      refreshDirectory(modal);
    })

    // Breadcrump and volume navigation
    modal.find('.sF-breadcrumps').on('change', function () {
      moveToDir(button, modal, this);
    })

    // File window
    modal.find('.sF-fileWindow')
      .on('click', function () {
        modal.find('.sF-fileList .selected').toggleClass('selected');
        toggleSelectButton(modal);
      })
      .on('click', '.sF-file, .sF-directory', function (event) {
        elementSelector(event, this, true, false);
        if (!$(this).hasClass('sF-directory')) {
          var name = $(this).find('.sF-file-name>div').text();
          setFilename(modal, name);
        }
        return false;
      })

    //Folder Text Selection
    modal.find('.sF-textChoice').on('click', function () {
      var directory = getCurrentDirectory(modal);
      var disabled = $(this).find('button').prop('disabled')
      if (!disabled) {
        $(this).toggleClass('open')
          .find('button.sF-btn-textChoice').toggleClass('active');
        if ($(this).hasClass('open')) {
          $(this).find('input').val(directory.root + directory.path.join("/")).focus();
          $(this).find('.input-group-btn>button').prop('disabled', true);
        }
      }
      return false;
    })
    modal.find('.sF-textChoice input').on('keyup', function (e) {
      var disabled = $(this).val() == '';
      $(this).parent().find('button').prop('disabled', disabled);
      if (e.keyCode == 13) {
        e.stopPropagation();
        setPathFromTextInput($(this).val(), modal);
      } else if (e.keyCode == 27) {
        var parent = $(this).closest('.sF-textChoice');
        parent.toggleClass('open', false)
          .find('button.sF-btn-textChoice').toggleClass('active', true);
      }
    })
    modal.find('.sF-textChoice ul').on('click', function () {
      return false;
    })
    modal.find('.sF-textChoice ul button').on('click', function () {
      var name = $(this).closest('.input-group').find('input').val();
      setPathFromTextInput(name, modal);
    })


    // Folder creation
    modal.find('.sF-newDir').on('click', function () {
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
    modal.find('.sF-newDir input').on('keyup', function (e) {
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
    modal.find('.sF-newDir ul').on('click', function () {
      return false;
    })
    modal.find('.sF-newDir ul button').on('click', function () {
      var name = $(this).closest('.input-group').find('input').val();
      createFolder(name, modal);
    })

    // Filenaming
    modal.find('.sF-filenaming')
      .on('click', '.input-group-btn.sF-filetype', function () {
        $(this).toggleClass('open')
          .find('button').toggleClass('active');
        return false;
      })
      .on('click', '.input-group-btn.sF-filetype li', function () {
        selectFiletype($(this));
        modal.trigger('change');
      })
    modal.find('.sF-filename').on('input', function () {
      modal.trigger('change');
    })

    // Custom events
    modal
      .on('change', function () {
        setDisabledButtons(button, modal);
        evalFilename(modal);
      })
      .on('fileSort', function (elem, attribute, direction) {
        $(button).data('sort', attribute).data('sortDir', direction);
        sortFiles(modal, attribute, direction);
      });


    // Binding data
    modal.data('backdrop', backdrop);
    modal.data('button', button);
    $(button).data('modal', modal);

    // Setting states
    var view = $(button).data('view') || 'sF-btn-icon';
    changeView(button, modal, modal.find('#' + view));
    modal.find('.sF-filename').focus();

    // Ready to enter
    setTimeout(function () {
      if ($('#shiny-modal').length == 0) {
        modal.detach().appendTo('body')
      } else {
        modal.detach().appendTo('#shiny-modal')
      }
      modal.addClass('in');
      backdrop.addClass('in');
    }, 1);

    populateFileChooser(button, $(button).data('dataCache'), false);
  };

  var addFiletypeChoice = function (button, modal) {
    var filetypes = $(button).data('filetype');
    var inputGroup = $(modal).find('.sF-filenaming');

    if (filetypes.length == 1) {
      if (filetypes[0] == null) return;
      inputGroup.append(
        $('<span>', { text: filetypes[0].ext[0] })
          .addClass('input-group-addon sF-filetype')
          .data('filetype', filetypes[0])
      )
    } else {
      inputGroup.append(
        $('<div>').addClass('input-group-btn sF-filetype').append(
          $('<button>', { type: 'button' }).addClass('btn btn-default dropdown-toggle')
        ).append(
          $('<ul>', { role: 'menu' }).addClass('dropdown-menu dropdown-menu-right')
        )
      );
      var typeSelect = inputGroup.find('.sF-filetype ul');
      filetypes.forEach(function (d, i) {
        typeSelect.append(
          $('<li>').append(
            $('<a>', { href: '#', text: d.name + ' (' + d.ext.join(', ') + ')' })
          ).data('filetype', d)
        )
      })
      selectFiletype(typeSelect.find('li:first-child'));
    }
  }

  var selectFiletype = function (element) {
    var button = element.closest('.sF-filetype').children('button');
    var filetype = element.data('filetype');

    button.text(filetype.ext[0] + ' ').append(
      $('<span>').addClass('caret')
    );
    element.closest('.sF-filetype').data('filetype', filetype);
  }

  var getFilename = function (modal) {
    var name = modal.find('.sF-filename').val();
    var type = null;

    if (name != '') {
      var filetype = modal.find('.sF-filetype').data('filetype');
      if (filetype !== undefined) {
        var hasExt = filetype.ext.some(function (d) {
          var regex = new RegExp(d + '$', 'i');
          return regex.test(name)
        });
        if (!hasExt) {
          name = name + filetype.ext[0];
        }
        type = filetype.name;
      }
    }

    return { name: name, type: type };
  }

  var evalFilename = function (modal) {
    var parent = modal.find('.sF-filenaming');
    var name = getFilename(modal).name;
    modal.find('#sF-selectButton').prop('disabled', name == '' || modal.find('.sF-warning').length != 0);
    if (nameExist(modal, name)) {
      parent.toggleClass('has-feedback', true)
        .toggleClass('has-warning', true);
      if (parent.find('#filenameWarn').length == 0) {
        parent.find('.sF-filename').after(
          $('<span>', { id: 'filenameWarn' }).addClass('glyphicon glyphicon-warning-sign form-control-feedback')
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

  var nameExist = function (modal, name) {
    var files = modal.find('.sF-file .sF-file-name div').map(function () { return $(this).text() }).get();
    return files.indexOf(name) != -1;
  }

  var setFilename = function (modal, name) {
    var filetype = modal.find('.sF-filetype').data('filetype');
    var extRegex = /\.[^.]*$/;
    var removeExt = false;
    if (filetype !== undefined) {
      var hasExt = filetype.ext.map(function (d) {
        var regex = new RegExp(d + '$', 'i');
        return regex.test(name)
      });
      if (hasExt.some(function (d) { return d; })) {
        if (hasExt[0]) {
          removeExt = true;
        }
      } else {
        removeExt = true;
      }
    }
    if (removeExt) {
      name = name.replace(extRegex, '');
    }
    modal.find('.sF-filename').val(name);
    modal.trigger('change');
  }

  var saveFile = function (modal, button) {
    var dir = getCurrentDirectory(modal);
    var file = getFilename(modal);
    $.extend(file, dir);

    $(button).data('file', file)
      .trigger('save', file);

    removeFileChooser(button, modal, file);
  }
  // File saver ends

  // Directory chooser
  var createDirChooser = function (button, title) {

    // Preparations
    $(button).prop('disabled', true);

    initializeButton(button);

    // Create the dialog
    var modal = $('<div>', { id: $(button).attr('id') + '-modal' }).addClass('sF-modalContainer modal fade').css('display', 'block').append(
      $('<div>').addClass('sF-modal modal-dialog modal-lg').append(
        $('<div>').addClass('modal-content').append(
          $('<div>').addClass('modal-header').append(
            $('<h4>', { text: title }).addClass('sF-title modal-title')
          ).append(
            $('<button>', { html: '&times;', type: 'button' }).addClass('close')
          )
        ).append(
          $('<div>').addClass('modal-body').append(
            $('<div>').addClass('sF-navigation btn-toolbar').append(
              $('<div>').addClass('sF-newDir dropdown btn-group btn-group-sm').append(
                $('<button>', { id: 'sF-btn-newDir', text: ' Create new folder' }).addClass('btn btn-default dropdown-toggle').prepend(
                  $('<span>').addClass('glyphicon glyphicon-folder-close')
                )
              ).append(
                $('<ul>').addClass('dropdown-menu').append(
                  $('<li>').append(
                    $('<div>').addClass('input-group input-group-sm').append(
                      $('<input>', { type: 'text', placeholder: 'Folder name', spellcheck: 'false' }).addClass('form-control')
                    ).append(
                      $('<span>').addClass('input-group-btn').append(
                        $('<button>', { type: 'button' }).addClass('btn btn-default').prop('disabled', true).append(
                          $('<span>').addClass('glyphicon glyphicon-plus-sign')
                        )
                      )
                    )
                  )
                )
              )
            ).append(
              $('<div>').addClass('sF-sort dropdown btn-group btn-group-sm').append(
                $('<button>', { id: 'sF-btn-sort', text: ' Sort content' }).addClass('btn btn-default dropdown-toggle').prepend(
                  $('<span>').addClass('glyphicon glyphicon-sort-by-attributes')
                )
              ).append(
                $('<ul>').addClass('dropdown-menu').append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Name' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Name' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Type' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Type' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Size' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Size' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Created' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Created' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('sortAttr').append(
                    $('<a>', { href: '#', text: 'Modified' }).prepend($('<span>').addClass('glyphicon glyphicon-ok'))
                  ).addClass($(button).data('sort') == 'Modified' ? 'selected' : '')
                ).append(
                  $('<li>').addClass('divider')
                ).append(
                  $('<li>').addClass('sortDir').append(
                    $('<a>', { href: '#', text: 'Sort direction' }).addClass($(button).data('sortDir')).prepend($('<span>').addClass('glyphicon glyphicon-arrow-down')).prepend($('<span>').addClass('glyphicon glyphicon-arrow-up'))
                  )
                )
              )
            ).append(
              $('<div>').addClass('sF-textChoice btn-group input-group-btn btn-group-sm').append(
                $('<button>', { id: 'sF-btn-textChoice', text: '' }).addClass('btn btn-default dropdown-toggle').prepend(
                  $('<span>').addClass('glyphicon glyphicon-pencil')
                )
              ).append(
                $('<ul>').addClass('dropdown-menu').append(
                  $('<li>').append(
                    $('<div>').addClass('input-group input-group-sm').append(
                      $('<input>', { type: 'text', placeholder: 'Enter Path' }).addClass('form-control')
                    ).append(
                      $('<span>').addClass('input-group-btn').append(
                        $('<button>', { type: 'button' }).addClass('btn btn-default').prop('disabled', true).append(
                          $('<span>').addClass('glyphicon glyphicon-ok-sign')
                        )
                      )
                    )
                  )
                )
              )
            ).append(
              $('<div>').addClass('sF-refresh btn-group btn-group-sm').append(
                $('<button>', { id: 'sF-btn-refresh' }).addClass('btn btn-default').append(
                  $('<span>').addClass('glyphicon glyphicon-refresh')
                )
              )
            ).append(
              $('<select>').addClass('sF-breadcrumps form-control input-sm')
            )
          ).append(
            $('<div>').addClass('sF-dirWindow').append(
              $('<div>').addClass('sF-dirInfo col-md-7').append(
                $('<h6>', { text: 'Directories' })
              ).append(
                $('<div>').append(
                  $('<div>').addClass('sF-dirList').append(
                    $('<div>')
                  )
                )
              )
            ).append(
              $('<div>').addClass('sF-dirInfo col-md-5').append(
                $('<h6>', { text: 'Content' })
              ).append(
                $('<div>').append(
                  $('<div>').addClass('sF-dirContent')
                )
              )
            )
          )
        ).append(
          $('<div>').addClass('sF-responseButtons modal-footer').append(
            $('<button>', { text: 'Cancel', type: 'button', id: 'sF-cancelButton' }).addClass('btn btn-default')
          ).append(
            $('<button>', { text: 'Select', type: 'button', id: 'sF-selectButton' }).addClass('btn btn-primary')
          )
        )
      )
    ).appendTo($('body'));

    var backdrop = $('<div>')
      .addClass('sF-modalBackdrop modal-backdrop fade')
      .appendTo($('body'));

    // HANDLER FUNCTION ATTACHMENT

    // Dismissers and selecters
    modal.find('.modal-header button.close').on('click', function () {
      dismissFileChooser(button, modal)
    })
    modal.find('.sF-responseButtons #sF-cancelButton').on('click', function () {
      dismissFileChooser(button, modal);
    })
    modal.find('.sF-responseButtons #sF-selectButton').on('click', function () {
      selectFiles(button, modal);
    })

    //Folder Text Selection
    var getCurrentDirectoryFolderSelection = function (modal) {
      var path = getPath($(modal).find('.sF-dirList .selected'));
      $(button).data('directory', path)
        .trigger('selection', path);
      var data = {
        path: path,
        root: $(modal).data('currentData').selectedRoot
      };
      return data;
    }

    modal.find('.sF-textChoice').on('click', function () {
      var directory = getCurrentDirectoryFolderSelection(modal);
      var disabled = $(this).find('button').prop('disabled')
      if (!disabled) {
        $(this).toggleClass('open')
          .find('button.sF-btn-textChoice').toggleClass('active');
        if ($(this).hasClass('open')) {
          $(this).find('input').val(directory.root + directory.path.join("/")).focus();
          $(this).find('.input-group-btn>button').prop('disabled', true);
        }
      }
      return false;
    })
    var setPathFromTextInputFolderSelection = function (path, modal) {
      if (path != '') {
        var currentDir = getCurrentDirectoryFolderSelection(modal);
        var date = new Date();
        var data = {
          name: path,
          path: currentDir.path,
          root: currentDir.root,
          id: date.getTime()
        }

        var breadcrumps = modal.find('.sF-breadcrumps')
        var volumes = breadcrumps.find('optgroup option')

        //Set a new root, if there is a match in the text path
        var foundRoot = false;
        $(volumes).each(function (i, volume) {
          if (path.startsWith($(volume).val())) {
            foundRoot = true;
            if (data.root != $(volume).val()) {
              data.root = $(volume).val();
              modal.data('currentData').selectedRoot = data.root;
            }
            data.path = path.substr(data.root.length).split(/[/\\]/);
          }
        })


        if (!foundRoot) {
          var searchPattern = new RegExp(/^[/\\]/);
          if (searchPattern.test(path)) { //From the root
            data.path = path.split(/[/\\]/);
          } else { //relative path
            data.path.push(path.split(/[/\\]/));
          }
        }

        //deselect selected elements
        $('.sF-dirList .selected').toggleClass('selected');
        parent = $(".sF-dirList .sF-directory :contains(" + data.root + ")").closest(".sF-directory");

        //traverse the new path and expand directories
        if (!parent.hasClass('empty')) {
          modal.data('currentData').tree = new Object();
          tree = modal.data('currentData').tree;
          tree.name = "";
          tree.expanded = false;
          tree.empty = true;
          tree.children = new Array(0);
          var tpath = JSON.parse(JSON.stringify(data.path))
          tpath.shift();
          for (name of tpath) {
            tree.expanded = true;
            tree.empty = false;
            tree.children = new Array(new Object);
            tree = tree.children[0];
            tree.name = name
            tree.expanded = false;
            tree.empty = true;
            tree.children = new Array(0);
          }
        }

        //select the final path element
        parent.toggleClass('selected');

        $(modal).find('.sF-textChoice').toggleClass('open', false)
          .find('.sF-btn-textChoice').toggleClass('active', false);

        modal.data('currentData').contentPath = data.path;

        Shiny.onInputChange($(button).attr('id') + '-modal', modal.data('currentData'));

      }
      return false;
    };

    modal.find('.sF-textChoice input').on('keyup', function (e) {
      var disabled = $(this).val() == '';
      $(this).parent().find('button').prop('disabled', disabled);
      if (e.keyCode == 13) {
        e.stopPropagation();
        setPathFromTextInputFolderSelection($(this).val(), modal);
      } else if (e.keyCode == 27) {
        var parent = $(this).closest('.sF-textChoice');
        parent.toggleClass('open', false)
          .find('button.sF-btn-textChoice').toggleClass('active', true);
      }
    })
    modal.find('.sF-textChoice ul').on('click', function () {
      return false;
    })
    modal.find('.sF-textChoice ul button').on('click', function () {
      var name = $(this).closest('.input-group').find('input').val();
      setPathFromTextInputFolderSelection(name, modal);
    })

    // Create dir
    modal.find('.sF-newDir').on('click', function () {
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
    modal.find('.sF-newDir input').on('keyup', function (e) {
      var disabled = $(this).val() == '';
      $(this).parent().find('button').prop('disabled', disabled);
      if (e.keyCode == 13) {
        // Enter
        createFolder($(this).val(), modal);
      } else if (e.keyCode == 27) {
        // Escape
        var parent = $(this).closest('.sF-newDir');
        parent.toggleClass('open', false)
          .find('button.sF-btn-newDir').toggleClass('active', true);
      }
    })
    modal.find('.sF-newDir ul').on('click', function () {
      return false;
    })
    modal.find('.sF-newDir ul button').on('click', function () {
      var name = $(this).closest('.input-group').find('input').val();
      createFolder(name, modal);
    })

    // Sort content
    modal.find('.sF-sort').on('click', function () {
      $(this).toggleClass('open')
        .find('button').toggleClass('active');
      return false;
    })
    modal.find('.sF-sort ul')
      .on('click', 'li.sortAttr', function () {
        $(this).siblings('.sortAttr').removeClass('selected');
        $(this).toggleClass('selected', true);
        $(modal).trigger('fileSort', [$(this).find('a').text(), $(this).siblings('.sortDir').find('a').attr('class')])
      })
      .on('click', 'li.sortDir', function () {
        $(this).find('a').toggleClass('ascending').toggleClass('descending')
        $(modal).trigger('fileSort', [$(this).parent().find('.selected a').text(), $(this).find('a').attr('class')])
      })

    // Set volume
    modal.find('.sF-breadcrumps').on('change', function () {
      changeVolume($(this).val(), modal);
    })

    // Directory tree
    modal.find('.sF-dirList')
      .on('click', '.sF-expander>span', function (e) {
        toggleExpander($(this), modal, button);
      })
      .on('click', '.sF-file-icon, .sF-file-name', function (e) {
        selectFolder($(this), modal, button);
      })

    // Refresh
    modal.find('.sF-refresh').on('click', function (e) {
      e.preventDefault();
      refreshDirectory(modal);
    })

    // Custom events
    modal
      .on('change', function () {
        setDisabledButtons(button, modal);
      })
      .on('fileSort', function (elem, attribute, direction) {
        $(button).data('sort', attribute).data('sortDir', direction);
        sortFiles(modal, attribute, direction);
      });

    // Attach relevant data
    modal.data('backdrop', backdrop);
    modal.data('button', button);
    $(button).data('modal', modal);

    // Set relevant states
    var view = $(button).data('view') || 'sF-btn-icon';
    changeView(button, modal, modal.find('#' + view));

    // Ready to enter
    setTimeout(function () {
      if ($('#shiny-modal').length == 0) {
        modal.detach().appendTo('body')
      } else {
        modal.detach().appendTo('#shiny-modal')
      }
      modal.addClass('in');
      backdrop.addClass('in');
    }, 1);

    populateDirChooser(button, $(button).data('dataCache'));
  };

  var populateDirChooser = function (element, data) {
    var modal = $(element).data('modal');

    $(element).data('dataCache', data);

    if (!modal || !data) return;

    var currentData = modal.data('currentData');

    var dirTree = modal.find('.sF-dirList>div');

    updateTree(dirTree, data.tree, data.contentPath);

    dirTree.addClass('root').children('.sF-file-name').children().text(data.selectedRoot);

    var breadcrumps = modal.find('.sF-breadcrumps')
    breadcrumps.find('option, optgroup').remove();

    var rootList = $('<optgroup>', { label: 'Volumes' }).appendTo(breadcrumps);
    data.rootNames.forEach(function (d) {
      rootList.append(
        $('<option>', { text: d })
      )
    })
    breadcrumps.val(data.selectedRoot);

    var dirContent = modal.find('.sF-dirContent');
    dirContent.addClass('measuring').children().remove();

    if (data.content == null) {
      dirContent.toggleClass('message', true).append(
        $('<div>').text('No folder selected')
      );
    } else if (data.content.filename.length == 0) {
      dirContent.toggleClass('message', true).append(
        $('<div>').text('Empty folder')
      );
    } else {
      dirContent.toggleClass('message', false)
      data.content.filename.forEach(function (file, i) {
        var d = {
          name: file,
          isDir: data.content.isdir[i],
          extension: data.content.extension[i],
          size: data.content.size[i],
          mTime: new Date(data.content.mtime[i]),
          cTime: new Date(data.content.ctime[i]),
          aTime: new Date(data.content.atime[i])
        };
        dirContent.append(
          $('<div>').toggleClass('sF-file', !d.isDir).toggleClass('sF-directory', d.isDir).append(
            $('<div>').addClass('sF-file-icon').addClass('sF-filetype-' + d.extension)
          ).append(
            $('<div>').addClass('sF-file-name').append(
              $('<div>', { text: d.name })
            )
          ).append(
            $('<div>', { text: d.isDir ? '' : formatSize(d.size, true) }).addClass('sF-file-size')
          ).data('sF-file', d)
        );
      })
    }
    var sizeCell = dirContent.find('.sF-file-size');
    var width = Math.max.apply(null, sizeCell.map(function () { return $(this).width() }));
    sizeCell.css('width', width + 'px');
    dirContent.removeClass('measuring');

    toggleSelectButton(modal);
    setPermission(modal, data.writable);
    setExists(modal, data.exist);

    modal.data('currentData', data);
    $(modal).trigger('change');
  };

  var updateTree = function (element, tree, selectPath) {
    var selected = false;
    var childSelection = null;
    element.toggleClass('sF-directory', true);
    if (!tree) return;
    if (selectPath != null) {
      if (selectPath[0] == tree.name) {
        if (selectPath.length == 1) {
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
    if (tree.empty) {
      element.removeClass('expanded closed');
    } else {
      element.toggleClass('expanded', tree.expanded);
      element.toggleClass('closed', !tree.expanded);
    }

    if (element.children().length == 0) {
      element.append(
        $('<div>').addClass('sF-expander').append(
          $('<span>').addClass('glyphicon glyphicon-triangle-right')
        )
      ).append(
        $('<div>').addClass('sF-file-icon')
      ).append(
        $('<div>').addClass('sF-file-name').append(
          $('<div>', { text: tree.name })
        )
      ).append(
        $('<div>').addClass('sF-content')
      )
    }
    if (!tree.expanded) {
      element.children('.sF-content').children().remove();
    } else {
      var parent = element.children('.sF-content');
      var children = parent.children();
      var oldChildren = [];
      var removedChildren = [];
      children.each(function (index) {
        var childElem = $(this);
        var childName = childElem.children('.sF-file-name').children().text();
        var remove = true;
        for (var i = 0; i < tree.children.length; i++) {
          if (tree.children[i] != null && childName == tree.children[i].name) {
            updateTree(childElem, tree.children[i], selectPath);
            oldChildren.push(i);
            remove = false;
            break;
          }
        }
        if (remove) removedChildren.push(index);
      })
      tree.children.forEach(function (val, i) {
        if (oldChildren.indexOf(i) == -1) {
          var newBranch = $('<div>');
          updateTree(newBranch, val, selectPath);
          newBranch.appendTo(parent);
        }
      })
      var removedElements = children.filter(function (i) { return removedChildren.indexOf(i) != -1; });
      removedElements.remove();
      var currentChildren = parent.children();
      currentChildren.detach().sort(function (a, b) {
        var comp = $(a).find('.sF-file-name>div').text().toLowerCase() < $(b).find('.sF-file-name>div').text().toLowerCase();
        return comp ? -1 : 1;
      })
      parent.append(currentChildren);
    }
  };

  var selectFolder = function (element, modal, button) {
    var deselect = element.closest('.sF-directory').hasClass('selected');
    var list = element.closest('.sF-dirList');
    list.find('.selected').toggleClass('selected');

    function scrollToSelected() {
      var modal = $('.sF-modalContainer');
      var button = $(modal.data('button'));
      var dirFlag = button.hasClass('shinyDirectories');

      if (dirFlag) {
        var buffer = list.children()[0].offsetTop;
        var itemOffset = $(element)[0].offsetTop - buffer;
        var scrollElement = $('.sF-dirInfo>div');
        var scrollPosition = scrollElement[0].scrollTop;
        var elementHeight = $(element).find('sF-file-icon').outerHeight(true);

        if (itemOffset < scrollPosition) {
          scrollElement[0].scrollTop = itemOffset;
        } else if (itemOffset + elementHeight > scrollPosition + scrollElement.height()) {
          scrollElement[0].scrollTop = itemOffset - scrollElement.height() + elementHeight;
        }
      } // NOTE: Only handle directory modal
    }

    if (deselect) {
      var path = null;
    } else {
      var path = getPath(element);
      element.closest('.sF-directory').toggleClass('selected');
      scrollToSelected();
    }

    setDisabledButtons(button, modal);
    toggleSelectButton(modal);

    if (modal.data('currentData')) {
      modal.data('currentData').contentPath = path;
      Shiny.onInputChange($(button).attr('id') + '-modal', modal.data('currentData'));
    }

    return false;
  };

  var toggleExpander = function (element, modal, button) {
    var parent = $(element.closest('.sF-directory')[0]);

    if (!parent.hasClass('empty')) {
      var path = getPath(element);
      if (parent.find('.selected').length != 0) {
        modal.data('currentData').contentPath = path.slice();
      }
      path.shift();
      if (modal.data('currentData') && modal.data('currentData').tree) {
        var tree = modal.data('currentData').tree;
        while (true) {
          if (path.length == 0) {
            tree.expanded = !tree.expanded;
            break;
          } else {
            var name = path.shift();
            tree = tree.children.filter(function (f) {
              if (f == null) {
                return null;
              } else {
                return f.name == name;
              }
            })[0];
          }
        }
        Shiny.onInputChange($(button).attr('id') + '-modal', modal.data('currentData'));
      }
    }
    return false;
  };

  var createFolder = function (name, modal) {
    if (name != '') {
      var button = $($(modal).data('button'));

      if (button.hasClass('shinySave')) {
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
        if (directory.length != 1) return
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
      Shiny.onInputChange(button.attr('id') + '-newDir', data);
      $(modal).find('.sF-newDir').toggleClass('open', false)
        .find('.sF-btn-newDir').toggleClass('active', false);
    }
  };

  var setPathFromTextInput = function (path, modal) {
    if (path != '') {
      var button = $($(modal).data('button'));
      var currentDir = getCurrentDirectory(modal);
      var date = new Date();
      var data = {
        name: path,
        path: currentDir.path,
        root: currentDir.root,
        id: date.getTime()
      }

      var breadcrumps = modal.find('.sF-breadcrumps')
      var volumes = breadcrumps.find('optgroup option')

      //Set a new root, if there is a match in the text path
      var foundRoot = false;
      $(volumes).each(function (i, volume) {
        if (path.startsWith($(volume).val())) {
          data.root = $(volume).val();
          data.path = path.substr(data.root.length).split(/[/\\]/)
          foundRoot = true;
        }
      })
      if (!foundRoot) {
        var searchPattern = new RegExp(/^[/\\]/);
        if (searchPattern.test(path)) { //From the root
          data.path = path.split(/[/\\]/);
        } else { //relative path
          data.path.push(path.split(/[/\\]/));
        }
      }

      $(modal).find('.sF-textChoice').toggleClass('open', false)
        .find('.sF-btn-textChoice').toggleClass('active', false);


      modal.data('currentData').contentPath = data.path;
      Shiny.onInputChange($(button).attr('id') + '-modal', data);
      $(button).data('back').push(currentDir);
      $(button).data('forward', []);
    }
    return false;
  };

  var getPath = function (element) {
    if (element.hasClass('.sF-directory')) {
      var parent = element;
    } else {
      var parent = element.closest('.sF-directory');
    }

    var path = [parent.children('.sF-file-name').children().text()];
    while (true) {
      parent = parent.parent().parent();
      if (!parent.hasClass('sF-directory')) break;
      path.push(parent.children('.sF-file-name').children().text());
    };
    path.reverse();
    path[0] = '';
    return path;
  };

  var changeVolume = function (volume, modal) {
    var button = $(modal).data('button');
    var data = $(modal).data('currentData');

    data.selectedRoot = volume;
    data.content = null;
    data.contentPath = null;
    data.tree = {
      name: '',
      expanded: true
    };

    Shiny.onInputChange($(button).attr('id') + '-modal', data);
  };
  // Directory chooser ends

  var handleArrowKey = function (direction) {
    var modal = $('.sF-modalContainer');
    if (modal.is(":visible") && !($(modal.data('button')).hasClass("shinySave") && $('.sF-filename').is(":focus"))) {
      var single = $($(".sF-modalContainer").data('button')).data('selecttype') === "single";
      moveSelection(event, single, direction);
      event.preventDefault();
      event.stopPropagation();
    }
  }

  var sF = {};

  sF.init = function () {
    Shiny.addCustomMessageHandler('shinyFiles', function (data) {
      populateFileChooser($('.shinyFiles#' + data.id), parseFiles(data.dir), true);
    });
    Shiny.addCustomMessageHandler('shinyDirectories', function (data) {
      populateDirChooser($('.shinyDirectories#' + data.id), data.dir);
    });
    Shiny.addCustomMessageHandler('shinySave', function (data) {
      populateFileChooser($('.shinySave#' + data.id), parseFiles(data.dir), true);
    });

    Shiny.addCustomMessageHandler('shinyFiles-refresh', function (data) {
      populateFileChooser($('.shinyFiles#' + data.id), parseFiles(data.dir), true);
    });
    Shiny.addCustomMessageHandler('shinyDirectories-refresh', function (data) {
      populateDirChooser($('.shinyDirectories#' + data.id), data.dir);
    });
    Shiny.addCustomMessageHandler('shinySave-refresh', function (data) {
      populateFileChooser($('.shinySave#' + data.id), parseFiles(data.dir), true);
    });

    $(document).on('click', '.shinyFiles', function (e) {
      createFileChooser(this, $(this).data('title'));
    }).on('click', function (e) {
      $('.sF-modal .open').removeClass('open').find('button').removeClass('active');
    });

    $(document).on('click', '.shinyDirectories', function (e) {
      createDirChooser(this, $(this).data('title'));
    }).on('click', function (e) {
      $('.sF-modal .open').removeClass('open').find('button').removeClass('active');
    });

    $(document).on('click', '.shinySave', function (e) {
      createFileSaver(this, $(this).data('title'));
    }).on('click', function (e) {
      $('.sF-modal .open').removeClass('open').find('button').removeClass('active');
    });

    // Handle keypresses
    $(document).keydown(function (event) {
      switch (event.keyCode) {
        case 27:
          // Escape
          if ($("#sF-cancelButton").is(":visible") && !$("div.sF-newDir").hasClass("open")) {
            $("#sF-cancelButton").click();
          };

          break;
        case 37:
          // Left Arrow
          handleArrowKey("left");
          break;
        case 39:
          // Right Arrow
          handleArrowKey("right");
          break;
        case 38:
          // Up arrow
          handleArrowKey("up");
          break;
        case 40:
          // Down arrow
          handleArrowKey("down");
          break;
        case 13:

          // Enter
          if ($(".sF-modalContainer").is(":visible")) {
            var modalButton = $($(".sF-modalContainer").data('button'));
            var lastElement = $(".sF-fileList").data('lastElement');

            if (modalButton.hasClass("shinyFiles")) {
              if (!$($(".sF-fileList").data('lastElement')).hasClass('selected')) { return; }

              // Select File
              if ($($(".sF-fileList").data('lastElement')).hasClass('sF-file')) {
                selectFiles(modalButton, $(".sF-modalContainer"));
              } else if ($($(".sF-fileList").data('lastElement')).hasClass('sF-directory')) {
                openDir(modalButton, $(".sF-modalContainer"), $($(".sF-fileList").data('lastElement')));
              }
            } else if (modalButton.hasClass("shinySave")) {
              // Assume the button is properly disabled/enabled
              if ($('.sF-filename').is(":focus") || $($(".sF-fileList").data('lastElement')).hasClass('sF-file')) {
                var filename = $(".sF-filename").val();
                var parts = filename.split(".");

                if ($("#sF-selectButton").prop('disabled')) { return; }

                // Do not use enter to submit an empty filename (just a file extension)
                if (($(".sF-filetype").length > 0 && filename.length > 0) || parts.slice(0, parts.length - 1).join(".").length > 0) {
                  saveFile($('.sF-modalContainer'), modalButton);
                }
              } else if ($($(".sF-fileList").data('lastElement')).hasClass('sF-directory')) {
                openDir(modalButton, $(".sF-modalContainer"), $($(".sF-fileList").data('lastElement')));
              }
            } else if (modalButton.hasClass("shinyDirectories")) {
              // Save File
              if ($($(".sF-dirList").find(".selected")).length === 1) {
                selectFiles(modalButton, $(".sF-modalContainer"));
              }
            }
          }
      }
    });

    // Close modal when clicking on backdrop
    $(document).on('click', '.sF-modalContainer', function (e) {
      if (!$(e.target).closest('.modal-content').length > 0 && $("#sF-cancelButton").is(":visible")) {
        $("#sF-cancelButton").click();
      }
    });
  };

  return sF;
})();

$(document).ready(function () {
  shinyFiles.init();
});
