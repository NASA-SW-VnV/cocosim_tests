#!/usr/bin/env python3
import os
from datetime import datetime
import subprocess
import argparse


PWD = ""
HOST = "https://babelfish.arc.nasa.gov/trac/cocosim_tests/changeset/"
BROWSE_FILE = "https://babelfish.arc.nasa.gov/trac/cocosim_tests/browser/"
HTML_DATE_COLUMnS = ['Date', '#Tests', '#Valid',
                    '#Failed', '#Broken', '#Unsupported']
COLORS = ['', 'table-success', 'table-danger', 'table-danger', '']


class Lustrec_test:
    def __init__(self, data):
        self.data = data

    def __str__(self):
        return self.data['model_name'] + self.data['commit_hash'][:7]


def get_git_hash(path):
    assert os.path.isfile(path)
    cmd = ['git', 'log', '-n', '1', '--pretty=format:%H', '--', path]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    commit_hash = proc.stdout.read().decode()
    return commit_hash


def get_git_author(path):
    assert os.path.isfile(path)
    cmd = ['git', 'log', '-n', '1', '--pretty=format:%an', '--', path]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    commit_hash = proc.stdout.read().decode()
    return commit_hash


def find_files(path, startwith, ext):
    res = []
    for root, _, files in os.walk(path):
        for f in files:
            filename, file_extension = os.path.splitext(f)
            if filename.startswith(startwith) and file_extension == ext:
                file_path = os.path.join(root, f)
                #  check if the file is commited by checking its hash
                commit_hash = get_git_hash(file_path)
                if commit_hash:  # if the file have a hash
                    res.append(file_path)
    return res


def parse_cvs(path):
    assert os.path.isfile(path)
    res = []
    date_time_str = os.path.basename(path).split('_')[-1]
    date_time = datetime.strptime(date_time_str, '%d-%m-%Y@%H%M%S.csv')
    with open(path) as file:
        # take first line and remove carriage return
        header = file.readline().rstrip().split(',')
        commit_hash = get_git_hash(path)
        for line in file.readlines():
            data = {}
            line = line.rstrip().split(',')  # remove carriage return and split
            for key, value in zip(header, line):
                data[key] = value
            data['date_time'] = date_time
            data['commit_hash'] = commit_hash
            res.append(Lustrec_test(data))
    return res


def generate_detail_html(path, output):
    res = parse_cvs(path)
    filename = os.path.basename(path)
    date = str(res[0].data['date_time'])
    commit_hash = get_git_hash(path)
    columns_names = get_detail_columns(res)
    columns_path = [key for key in res[0].data.keys() if key.endswith('path')]
    title = '<h2>%s</h2>' % filename
    title += '<h4>Date: %s<br>' % date
    url = HOST + commit_hash
    title += 'Commit: <a href="%s">%s</a><br>' % (url, commit_hash[:7])
    title += 'Author: %s</h4>\n' % get_git_author(path)
    html = '<table id="main" class="table table-striped table-bordered" style="width:100%">\n'
    html += '\t<thead>\n'
    html += '\t\t<tr>\n'
    # head
    for columns in columns_names + columns_path:
        html += '\t\t\t<th>%s</th>\n' % columns.replace('_', ' ')
    html += '\t\t</tr>\n'
    html += '\t</thead>\n'
    html += '\t<tbody>\n'
    # body
    for test in res:
        data = test.data
        if get_success(data):
            html += '\t\t<tr>\n'
        else:
            html += '\t\t<tr class="table-danger">\n'
        for key in columns_names:
            html += '\t\t\t<td>%s</td>\n' % data.get(key, '')
        for key in columns_path:
            value = data.get(key, '')
            if value:
                relative_path = get_relative_path(value)
                url = BROWSE_FILE + relative_path + '?rev=' + commit_hash
            else:
                url = ''
            value = os.path.basename(value)
            html += '\t\t\t<th><a href="%s">%s</a></th>\n' % (url, value)

        html += '\t\t</tr>\n'
    html += '\t</tbody>\n'
    html += '</table>\n'

    template_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'template.html')
    with open(template_path) as file:
        template = file.read()
    file_path = os.path.join(output, filename + '.html')
    with open(file_path, 'w') as file:
        final_html = template.replace('{{title}}', title)
        final_html = final_html.replace('{{table}}', html)
        final_html = final_html.replace('{{order}}', '[1, "asc"], [2, "asc"]')
        file.write(final_html)


def get_detail_columns(res):
    valid_key = [key for key in res[0].data.keys() if key.endswith('valid')]
    failed_key = [key for key in res[0].data.keys() if key.endswith('failed')]
    unsupported_key = [
        key for key in res[0].data.keys() if key.endswith('unsupported')]
    return ['models_name'] + valid_key + failed_key + unsupported_key


def get_relative_path(path):
    path = os.path.normpath(path)
    list_path = path.split(os.sep)
    last_occurence_index = len(list_path) - \
        list_path[::-1].index('cocosim_tests')
    relative_path = os.sep.join(list_path[last_occurence_index:])
    return relative_path


def generate_index_html(csv_files, output):
    title = '<h2>Cocosim Regression Test Result</h2>\n'
    html = ''
    html += '<table id="main" class="table table-striped table-bordered table-sm" style="width:100%">\n'
    html += '\t<thead>\n'
    html += '\t\t<tr>\n'
    # head
    for columns in HTML_DATE_COLUMnS:
        html += '\t\t\t<th>%s</th>\n' % columns.replace('_', ' ')
    html += '\t\t</tr>\n'
    html += '\t</thead>\n'
    html += '\t<tbody>\n'
    # body
    for path in csv_files:
        res = parse_cvs(path)
        date = str(res[0].data['date_time'])
        num = gen_num(res)
        html += '\t\t<tr>\n'
        url = 'csv/' + os.path.basename(path) + '.html'
        html += '\t\t\t<th><a href="%s">%s</a></th>\n' % (url, date)
        for color, columns in zip(COLORS, num):
            html += '\t\t\t<th class="%s">%s</th>\n' % (color, columns)
        html += '\t\t</tr>\n'
    html += '\t</tbody>\n'
    html += '</table>\n'

    template_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'template.html')
    with open(template_path) as file:
        template = file.read()
    file_path = os.path.join(output, 'index.html')
    with open(file_path, 'w') as file:
        final_html = template.replace('{{title}}', title)
        final_html = final_html.replace('{{table}}', html)
        final_html = final_html.replace('{{order}}', '[0, "desc"]')
        file.write(final_html)


def get_success(data):
    valid_key = [key for key in data.keys() if key.endswith('valid')]
    failed_key = [key for key in data.keys() if key.endswith('failed')]
    broken = sum([abs(int(data[key])) for key in failed_key])
    valid = sum([abs(int(data[key])) for key in valid_key])
    if broken > 0 or len(valid_key) > valid:
        return False
    else:
        return True


def gen_num(res):
    num_tests = len(res)
    num_valid = 0
    num_failed = 0
    num_unsupported = 0
    num_broken = 0
    valid_key = [key for key in res[0].data.keys() if key.endswith('valid')]
    failed_key = [key for key in res[0].data.keys() if key.endswith('failed')]
    unsupported_key = [
        key for key in res[0].data.keys() if key.endswith('unsupported')]
    for model in res:
        data = model.data
        broken = sum([abs(int(data[key])) for key in failed_key])
        unsupported = sum([abs(int(data[key])) for key in unsupported_key])
        valid = sum([abs(int(data[key])) for key in valid_key])
        if unsupported > 0:
            num_unsupported += 1
        elif broken > 0:
            num_broken += 1
        elif len(valid_key) > valid:
            num_failed += 1
        else:
            num_valid += 1
    return num_tests, num_valid, num_failed, num_broken, num_unsupported


if __name__ == '__main__':
    ''' Example of use :
        python3 scripts/generate_web.py -p Simulink/unitTests/test_result -d doc
    '''
    parser = argparse.ArgumentParser()
    parser.add_argument('--path', '-p', type=str,
                        help='path to test result (were all the cvs files are)')
    parser.add_argument('--output', '-d', type=str,
                        default='../doc', help='path to output dir')
    args = parser.parse_args()

    csv_files = find_files(os.path.abspath(args.path), 'LUSTREC', '.csv')

    output = os.path.abspath(args.output)
    csv_output = os.path.join(output, 'csv')
    if not os.path.isdir(csv_output):
        os.makedirs(csv_output, exist_ok=True)

    for path in csv_files:
        generate_detail_html(path, csv_output)
    generate_index_html(csv_files, args.output)
