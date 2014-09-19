var shinyFiles = (function() {
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
	            selectElementsBetweenIndexes([$(lastSelectedElement).index(), $(element).index()])
	        }
	    }
	};
	
	// Modified from Tomáš Zatos answer at http://stackoverflow.com/questions/7837456/comparing-two-arrays-in-javascript
	var compareArrays = function (arrayA, arrayB) {
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
	        }
	        else if (arrayA[i] != arrayB[i]) {
	            // Warning - two different object instances will never be equal: {x:20} != {x:20}
	            return false;
	        }
	    }
	    return true;
	};
	
	// From http://stackoverflow.com/questions/5223/length-of-javascript-object-ie-associative-array answer by James Coglan
	var objSize = function(obj) {
	    var size = 0, key;
	    for (key in obj) {
	        if (obj.hasOwnProperty(key)) size++;
	    }
	    return size;
	};
	
	// Adapted from https://gist.github.com/rodneyrehm/2818576
	$.fn.sortChildren = function(map, reverse) {
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
	
	var parseDir = function(data) {
		var parsedFiles = {};
		data.files.filename.forEach(function(d, i) {
			var mTime = data.files.mtime[i].split('-');
			var cTime = data.files.ctime[i].split('-');
			var aTime = data.files.atime[i].split('-');
			parsedFiles[d] = {
				name: d,
				extension: data.files.extension[i],
				isDir: data.files.isdir[i],
				size: data.files.size[i],
				mTime: new Date(mTime[0], mTime[1], mTime[2], mTime[3], mTime[4]),
				cTime: new Date(cTime[0], cTime[1], cTime[2], cTime[3], cTime[4]),
				aTime: new Date(aTime[0], aTime[1], aTime[2], aTime[3], aTime[4])
			};
		});
		
		return {
			files: parsedFiles,
			location: data.breadcrumps,
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
			return date.toLocaleString([], {weekday:'long', year:'numeric', month:'short', day:'numeric', hour:'2-digit', minute:'2-digit'})
		}
	};
	
	// Following function taken from http://stackoverflow.com/questions/10420352/converting-file-size-in-bytes-to-human-readable - Mark's answer
	var formatSize = function(bytes, si) {
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
		var back = $(button).data('back') || [];
		var forward = $(button).data('forward') || [];
		var view = $(button).data('view') || '';
		var sort = $(button).data('sort') || 'Name';
		var sortDir = $(button).data('sortDir') || 'ascending';
		
		$(button).data('back', back)
			.data('forward', forward)
			.data('view', view)
			.data('sort', sort)
			.data('sortDir', sortDir);
	};
	
	var setDisabledButtons = function(button, modal) {
		var back = $(button).data('back').length == 0;
		var forward = $(button).data('forward').length == 0;
		var up = $(modal).find('.sF-breadcrumps>option').length == 1;
		
		$(modal).find('#sF-btn-back').prop('disabled', back);
		$(modal).find('#sF-btn-forward').prop('disabled', forward);
		$(modal).find('#sF-btn-up').prop('disabled', up);
	};
	
	var filesSelected = function(modal) {
		return modal.find('.sF-fileList').children().filter('.sF-file.selected').length > 0;
	};
	
	var toggleSelectButton = function(modal) {
		modal.find('#sF-selectButton').prop('disabled', !filesSelected(modal));
	};
	
	var sortFiles = function(modal, attribute, direction) {
		var fileList = $(modal).find('.sF-fileList');
		
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
	
	var createFileChooser = function(button, title) {
		Shiny.unbindAll();
		
		$(button).prop('disabled', true);
		
		initializeButton(button);
		
		var modal = $('<div>', {id: $(button).attr('id')+'-modal'}).addClass('sF-modal sF-modalContainer modal fade').css('display', 'block').append(
			$('<div>').addClass('modal-header').append(
				$('<button>', {html: '&times;', type: 'button'}).addClass('close')
					.on('click', function() {
						dismissFileChooser(button, modal)
					})
			).append(
				$('<h4>', {text: title}).addClass('sF-title modal-title')
			)
		).append(
			$('<div>').addClass('modal-body').append(
				$('<div>').addClass('sF-navigation btn-toolbar').append(
					$('<div>').addClass('btn-group btn-group-sm sF-navigate').append(
						$('<button>', {id: 'sF-btn-back'}).addClass('btn btn-default').append(
							$('<i>').addClass('icon-chevron-left')
						).on('click', function() {
							moveBack(button, modal);
						})
					).append(
						$('<button>', {id: 'sF-btn-up'}).addClass('btn btn-default').append(
							$('<i>').addClass('icon-arrow-up')
						).on('click', function() {
							moveUp(button, modal);
						})
					).append(
						$('<button>', {id: 'sF-btn-forward'}).addClass('btn btn-default').append(
							$('<i>').addClass('icon-chevron-right')
						).on('click', function() {
							moveForward(button, modal);
						})
					)
				).append(
					$('<div>').addClass('btn-group btn-group-sm sF-view').append(
						$('<button>', {id: 'sF-btn-icon'}).addClass('btn btn-default').append(
							$('<i>').addClass('icon-th')
						)
					).append(
						$('<button>', {id: 'sF-btn-list'}).addClass('btn btn-default').append(
							$('<i>').addClass('icon-th-list')
						)
					).append(
						$('<button>', {id: 'sF-btn-detail'}).addClass('btn btn-default').append(
							$('<i>').addClass('icon-align-justify')
						)
					).on('click', 'button', function() {
						changeView(button, modal, $(this));
					})
				).append(
					$('<div>').addClass('sF-sort dropdown btn-group btn-group-sm').append(
						$('<button>', {id: 'sF-btn-sort'}).addClass('btn btn-default').css({
							'padding-left': '3px',
							'padding-right': '7px',
							'border-radius': '4px'
						}).append(
							$('<i>').addClass('icon-resize-vertical')
						).append(
							$('<i>').addClass('icon-signal').css({
								'-webkit-transform': 'rotate(90deg)',
							    '-moz-transform': 'rotate(90deg)',
							    '-ms-transform': 'rotate(90deg)',
							    '-o-transform': 'rotate(90deg)',
							    'transform': 'rotate(90deg)'
							})
						)
					).append(
						$('<ul>').addClass('dropdown-menu').append(
							$('<li>').addClass('sortAttr').append($('<a>', {href: '#', text: 'Name'}).prepend($('<i>').addClass('icon-ok'))).addClass($(button).data('sort') == 'Name' ? 'selected' : '')
						).append(
							$('<li>').addClass('sortAttr').append($('<a>', {href: '#', text: 'Type'}).prepend($('<i>').addClass('icon-ok'))).addClass($(button).data('sort') == 'Type' ? 'selected' : '')
						).append(
							$('<li>').addClass('sortAttr').append($('<a>', {href: '#', text: 'Size'}).prepend($('<i>').addClass('icon-ok'))).addClass($(button).data('sort') == 'Size' ? 'selected' : '')
						).append(
							$('<li>').addClass('sortAttr').append($('<a>', {href: '#', text: 'Created'}).prepend($('<i>').addClass('icon-ok'))).addClass($(button).data('sort') == 'Created' ? 'selected' : '')
						).append(
							$('<li>').addClass('sortAttr').append($('<a>', {href: '#', text: 'Modified'}).prepend($('<i>').addClass('icon-ok'))).addClass($(button).data('sort') == 'Modified' ? 'selected' : '')
						).append(
							$('<li>').addClass('divider')
						).append(
							$('<li>').addClass('sortDir').append($('<a>', {href: '#', text: 'Sort direction'}).addClass($(button).data('sortDir')).prepend($('<i>').addClass('icon-arrow-down')).prepend($('<i>').addClass('icon-arrow-up')))
						).on('click', 'li.sortAttr',  function() {
							$(this).siblings('.sortAttr').removeClass('selected');
							$(this).toggleClass('selected', true);
							
							$(modal).trigger('fileSort', [$(this).find('a').text(), $(this).siblings('.sortDir').find('a').attr('class')])
						}).on('click', 'li.sortDir', function() {
							$(this).find('a').toggleClass('ascending').toggleClass('descending')
							
							$(modal).trigger('fileSort', [$(this).parent().find('.selected a').text(), $(this).find('a').attr('class')])
						})
					).on('click', function() {
						$(this).toggleClass('open')
							.find('button').toggleClass('active');
						return false;
					})
				).append(
					$('<select>').addClass('sF-breadcrumps form-control input-sm').on('change', function() {
							moveToDir(button, modal, this);
						}).css({
							'width': 'calc(100% - 291px)',
							'margin-bottom': 0,
							'float': 'right'
						})
				)
			).append(
				$('<div>').addClass('sF-fileWindow').append(
					$('<div>').addClass('sF-fileList')
				).on('click', function() {
					modal.find('.sF-fileList .selected').toggleClass('selected');
					toggleSelectButton(modal);
				})
			)
		).append(
			$('<div>').addClass('sF-responseButtons modal-footer').append(
				$('<button>', {text: 'Cancel', type: 'button'}).addClass('btn btn-default')
					.on('click', function() {
						dismissFileChooser(button, modal);
					})
			).append(
				$('<button>', {text: 'Select', type: 'button', id: 'sF-selectButton'}).addClass('btn btn-primary')
					.on('click', function() {
						selectFiles(button, modal);
					})
			)
		).appendTo($('body'));
		
		var backdrop = $('<div>').addClass('modal-backdrop fade').appendTo($('body'));
		
		modal.data('backdrop', backdrop);
		modal.data('button', button);
		$(button).data('modal', modal);
		
		var view = $(button).data('view') || 'sF-btn-icon';
		changeView(button, modal, modal.find('#'+view));
		
		modal.on('change', function() {
			setDisabledButtons(button, modal);
		}).on('fileSort', function(elem, attribute, direction) {
			$(button).data('sort', attribute).data('sortDir', direction);
			sortFiles(modal, attribute, direction);
		});
		
		setTimeout(function() {
			modal.addClass('in');
			backdrop.addClass('in');
		}, 1);
		
		Shiny.bindAll();
        
        populateFileChooser(button, $(button).data('dataCache'));
	};
	
	var createFileChooserBootstrap3 = function(button, title) {
		Shiny.unbindAll();
		
		$(button).prop('disabled', true);
		
		initializeButton(button);
		
		var modal = $('<div>', {id: $(button).attr('id')+'-modal'}).addClass('sF-modalContainer modal fade').css('display', 'block').append(
			$('<div>').addClass('sF-modal modal-dialog').append(
				$('<div>').addClass('modal-content').append(
					$('<div>').addClass('modal-header').append(
						$('<button>', {html: '&times;', type: 'button'}).addClass('close')
							.on('click', function() {
								dismissFileChooser(button, modal)
							})
					).append(
						$('<h4>', {text: title}).addClass('sF-title modal-title')
					)
				).append(
					$('<div>').addClass('modal-body').append(
						$('<div>').addClass('sF-navigation btn-toolbar').append(
							$('<div>').addClass('btn-group btn-group-sm sF-navigate').append(
								$('<button>', {id: 'sF-btn-back'}).addClass('btn btn-default').append(
									$('<span>').addClass('glyphicon glyphicon-chevron-left')
								).on('click', function() {
									moveBack(button, modal);
								})
							).append(
								$('<button>', {id: 'sF-btn-up'}).addClass('btn btn-default').append(
									$('<span>').addClass('glyphicon glyphicon-arrow-up')
								).on('click', function() {
									moveUp(button, modal);
								})
							).append(
								$('<button>', {id: 'sF-btn-forward'}).addClass('btn btn-default').append(
									$('<span>').addClass('glyphicon glyphicon-chevron-right')
								).on('click', function() {
									moveForward(button, modal);
								})
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
							).on('click', 'button', function() {
								changeView(button, modal, $(this));
							})
						).append(
							$('<select>').addClass('sF-breadcrumps form-control input-sm').on('change', function() {
									moveToDir(button, modal, this);
								})
						)
					).append(
						$('<div>').addClass('sF-fileWindow').append(
							$('<div>').addClass('sF-fileList')
						).on('click', function() {
							modal.find('.sF-fileList .selected').toggleClass('selected');
							toggleSelectButton(modal);
						})
					)
				).append(
					$('<div>').addClass('sF-responseButtons modal-footer').append(
						$('<button>', {text: 'Cancel', type: 'button'}).addClass('btn btn-default')
							.on('click', function() {
								dismissFileChooser(button, modal);
							})
					).append(
						$('<button>', {text: 'Select', type: 'button'}).addClass('btn btn-primary').prop('disabled', true)
							.on('click', function() {
								selectFiles(button, modal);
							})
					)
				)
			)
		).appendTo($('body'));
		
		var backdrop = $('<div>').addClass('modal-backdrop fade').appendTo($('body'));
		
		modal.data('backdrop', backdrop);
		modal.data('button', button);
		$(button).data('modal', modal);
		
		var view = $(button).data('view') || 'sF-btn-icon';
		changeView(button, modal, modal.find('#'+view));
		
		modal.on('change', function() {
			setDisabledButtons(button, modal);
		});
		
		setTimeout(function() {
			modal.addClass('in');
			backdrop.addClass('in');
		}, 1);
		
		Shiny.bindAll();
	};
	
	var removeFileChooser = function(button, modal) {
		Shiny.unbindAll();
		
		var modal = $(modal).removeClass('in');
		var backdrop = $(modal).data('backdrop').removeClass('in');
		
		setTimeout(function() {
			modal.remove();
			backdrop.remove();
			Shiny.bindAll();
		}, 300);
		$(button).prop('disabled', false)
			.data('modal', null);
	};
	
	var dismissFileChooser = function(button, modal) {
		removeFileChooser(button, modal);
		$(button).trigger('cancel');
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
					).data('sF-file', d).on('click', function(event) {
						elementSelector(event, this, single, false);
						toggleSelectButton(modal);
						return false;
					})
				);
			};
			modal.find('.sF-directory').on('dblclick', function() {
				$(this).toggleClass('selected', true);
				openDir($(element), modal, this);
			});
		} else {
			if (objSize(oldFiles) > 0) {
				modal.find('.sF-fileList').children().filter(function() {
					return oldFiles[$(this).find('.sF-file-name div').text()]
				}).remove();
			};
			if (objSize(newFiles) > 0) {
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
						).data('sF-file', d).on('click', function(event) {
							elementSelector(event, this, single, false);
							toggleSelectButton(modal);
							return false;
						})
					);
				};
			};
		};
		
		setDisabledButtons($(element), modal);
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
	
	var selectFiles = function(button, modal) {
		var files = getSelectedFiles(modal);
		
		$(button).data('files', files)
            .trigger('fileselect', [files]);
        
        Shiny.onInputChange($(button).attr('id'), {
        	files: $.extend({}, files.files.toArray().map(function(d) {
				return d;
			})),
			root: files.root
		});
		
		removeFileChooser(button, modal);
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
		$(button).data('forward').push(currentDir);
	};
	
	var moveForward = function(button, modal) {
		$('.sF-btn-forward').prop('disabled', true);
		
		var newDir = $(button).data('forward').pop();
		var currentDir = getCurrentDirectory(modal);
		
		changeDirectory(button, modal, newDir);
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
		$(button).data('back').push(currentDir);
		$(button).data('forward', []);
	}
	
	var sF = {};
	
	sF.init = function() {
        Shiny.addCustomMessageHandler('shinyFiles', function(data) {
            populateFileChooser($('.shinyFiles#'+data.id), parseDir(data.dir));
        });
        
		$(document).on('click', '.shinyFiles', function(e) {
			createFileChooser(this, $(this).data('title'));
		}).on('click', function(e) {
			$('.sF-modal .open').removeClass('open').find('button').removeClass('active');
		});
	};
	
	return sF;
})();

$(document).ready(function() {
	shinyFiles.init();
});
