# Summary

Convert ESA page to Confluence page.

# Process

1. [Export Esa Page](https://docs.esa.io/posts/11)
2. [Get API KEY of Attlasian](https://id.atlassian.com/manage/api-tokens)
3. change script

```ruby
CONF_SPACE = '<SPACE_NAME>'
HOST = 'https://<MY DOMAIN>.atlassian.net'
EMAIL = '<EMAIL ADDRESS>'
TOKEN = '<TOKEN>'
DIR_PATH = '<UNZIP PATH>' # ex. './esa'
```

4. gem install

```bash
$ gem install faraday json redcarpet
```

5. Action

```bash
$ ruby export.rb 
```

## Reference

https://qiita.com/nullnull/items/f4121fcdca16892dcacb
