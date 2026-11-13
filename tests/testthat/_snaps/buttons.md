# shinyFilesButton markup is stable

    Code
      cat(as.character(make()))
    Output
      <button id="f" type="button" class="shinyFiles btn btn-default action-button" data-title="Title" data-selecttype="single" data-view="sF-btn-detail">Pick</button>

# shinyFilesLink markup is stable

    Code
      cat(as.character(make()))
    Output
      <a id="f" type="button" class="shinyFiles action-button" data-title="Title" data-selecttype="single" data-view="sF-btn-detail">Pick</a>

# shinyDirButton markup is stable

    Code
      cat(as.character(make()))
    Output
      <button id="f" type="button" class="shinyDirectories btn btn-default action-button" data-title="Title">Pick</button>

# shinyDirLink markup is stable

    Code
      cat(as.character(make()))
    Output
      <a id="f" type="button" class="shinyDirectories action-button" data-title="Title">Pick</a>

# shinySaveButton markup is stable

    Code
      cat(as.character(make()))
    Output
      <button id="f" type="button" class="shinySave btn btn-default action-button" data-title="Title" data-filetype="[null]" data-filename="" data-view="sF-btn-detail">Pick</button>

# shinySaveLink markup is stable

    Code
      cat(as.character(make()))
    Output
      <a id="f" type="button" class="shinySave action-button" data-title="Title" data-filetype="[null]" data-filename="" data-view="sF-btn-detail">Pick</a>

